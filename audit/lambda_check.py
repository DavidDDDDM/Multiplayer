#!/usr/bin/env python3
"""Check MP's ordinal-based lambda sync registrations against the installed game's IL.

SyncMethod.Lambda(typeof(T), nameof(T.M), N) resolves to the compiler-generated method '<M>b__N' (capturing,
inside '<>c__DisplayClass{id}_*') or '<M>b__{id}_N' (non-capturing, on T or T.'<>c'). A game update can reorder
lambdas, which makes N silently point at a different button. This prints, per registration, what lambda N
actually does in the installed game (calls + strings), next to MP's comment, for review.

Usage: audit/lambda_check.py [audit/decomp/acs.il] > audit/lambda_check.txt
The IL dump comes from: ilspycmd -il -r <Managed> <Managed>/Assembly-CSharp.dll > audit/decomp/acs.il
"""
import re, sys, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IL = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "audit/decomp/acs.il")

# ---- parse IL: every compiler-generated lambda body, keyed by (top-level type short name) ----
class_re = re.compile(r"^(\t*)\.class .*?(\S+)\s*$")
method_name_re = re.compile(r"'(<([^>]+)>b__(\d+_)?(\d+))'\s*\(")
end_method_re = re.compile(r"\} // end of method")
call_re = re.compile(r"\b(call|callvirt|newobj)\s.*?([\w\.`<>'\[\]/]+)::('[^']+'|[\w\.`]+)")
ldstr_re = re.compile(r'ldstr\s+"([^"]*)"')

lambdas = collections.defaultdict(list)  # top type short name -> [(parent, id or None, ordinal, holder, summary)]
stack = []
cur = None
pending_class = None
with open(IL, encoding="utf-8", errors="replace") as f:
    for line in f:
        m = class_re.match(line)
        if m:
            depth = len(m.group(1))
            del stack[depth:]
            name = m.group(2).strip("'")
            stack.append(name)
            continue
        if cur is None:
            mm = method_name_re.search(line)
            if mm and ("instance" in line or "static" in line or ".method" in line) and "ldftn" not in line and "ldsfld" not in line:
                cur = dict(parent=mm.group(2), id=(mm.group(3) or "").rstrip("_") or None,
                           ord=int(mm.group(4)), holder=stack[-1] if stack else "?",
                           top=stack[0].split(".")[-1] if stack else "?", ops=[])
            continue
        if end_method_re.search(line):
            lambdas[cur["top"]].append(cur)
            cur = None
            continue
        s = ldstr_re.search(line)
        if s:
            cur["ops"].append('"%s"' % s.group(1))
            continue
        st = re.search(r"\bstfld\s.*?::(\S+)$", line.strip())
        if st:
            cur["ops"].append("=" + st.group(1).strip("'"))
            continue
        c = call_re.search(line)
        if c:
            owner = c.group(2).split(".")[-1].split("/")[-1].strip("'")
            tgt = c.group(3).strip("'")
            if c.group(1) == "newobj":
                tgt = owner
            elif not tgt.startswith(("get_Item", "op_")):
                tgt = owner + "." + tgt
            cur["ops"].append(tgt)

def summarize(ops, n=8):
    out, seen = [], set()
    for o in ops:
        if o in seen or o in ("Invoke", "get_Count", "ToString", "Object", "TranslatorFormattedStringExtensions.Translate", "Translator.Translate", "TaggedString.op_Implicit"):
            continue
        seen.add(o)
        out.append(o)
    return ", ".join(out[:n])

# ---- parse MP registrations ----
reg_re = re.compile(r"(SyncMethod|SyncDelegate)\.(Lambda|LambdaInGetter)\(\s*typeof\(([\w\.]+)\)\s*,\s*"
                    r"(?:nameof\(([\w\.]+)\)|\"(\w+)\")\s*,\s*(\d+)\s*(\)|,)(.*)$")
regs = []
for dp, _, fs in os.walk(os.path.join(ROOT, "Source/Client")):
    for fn in fs:
        if not fn.endswith(".cs"):
            continue
        p = os.path.join(dp, fn)
        for i, line in enumerate(open(p, encoding="utf-8"), 1):
            if "Lambda" not in line or line.strip().startswith("//"):
                continue
            m = reg_re.search(line)
            if not m:
                if re.search(r"Sync(Method|Delegate)\.Lambda", line):
                    regs.append(dict(file=os.path.relpath(p, ROOT), line=i, raw=line.strip(), unparsed=True))
                continue
            typ = m.group(3).split(".")[-1]
            meth = (m.group(4) or m.group(5)).split(".")[-1]
            if m.group(2) == "LambdaInGetter":
                meth = "get_" + meth
            comment = ""
            cm = re.search(r"//\s*(.*)$", m.group(8))
            if cm:
                comment = cm.group(1)
            regs.append(dict(file=os.path.relpath(p, ROOT), line=i, kind=m.group(1), type=typ, meth=meth,
                             ord=int(m.group(6)), comment=comment, debug="SetDebugOnly" in m.group(8)))

def main():
    missing = 0
    for r in regs:
        if r.get("unparsed"):
            print(f"UNPARSED {r['file']}:{r['line']}  {r['raw']}")
            continue
        cands = [l for l in lambdas.get(r["type"], []) if l["parent"] == r["meth"] and l["ord"] == r["ord"]]
        ids = sorted({l["id"] for l in lambdas.get(r["type"], []) if l["parent"] == r["meth"]} - {None})
        tag = "DEV " if r["debug"] else "    "
        print(f"{r['file']}:{r['line']}  {tag}{r['kind']} {r['type']}.{r['meth']}[{r['ord']}]  // {r['comment']}")
        if not cands:
            missing += 1
            print("    !! NO LAMBDA with that ordinal in installed game")
        for c in cands:
            print(f"    -> {c['holder']}::<{c['parent']}>b__{(c['id'] + '_') if c['id'] else ''}{c['ord']}: {summarize(c['ops'])}")
    print(f"\n{len(regs)} registrations, {missing} unresolved", file=sys.stderr)


if __name__ == "__main__":
    main()
