#!/usr/bin/env python3
"""List Biotech UI lambdas that change game state but that MP does not sync (candidate desync gaps).

A lambda counts as covered when MP registers it by ordinal (SyncMethod/SyncDelegate.Lambda), or when it calls a
method MP registers (SyncMethod.Register) or patches ([MpPrefix]/[MpPostfix]). Everything else that writes a field
or calls a non-getter is printed with the strings around its ldftn site (the button label key) and a DEV flag
(dev-mode-only gizmos), for manual classification into docs/BIOTECH_SYNC_AUDIT.md.

Usage: audit/biotech_gaps.py > audit/biotech_gaps.txt   (needs audit/decomp/acs.il, see lambda_check.py)
"""
import os, re, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lambda_check as lc  # parses the IL + MP's ordinal registrations on import

BIOTECH = re.compile(r"Mech|Gene(?!ric|ral|rat)|Xeno|Deathrest|Hemogen|GrowthVat|Embryo|Ovum|Baby|Child|Pollut|Toxifier|"
                     r"Wastepack|Atomizer|Polux|BandNode|Subcore|Bandwidth|ControlGroup|Learning|Feeding|Pregnan|Labor|"
                     r"Bossgroup|Bloodfeed|Sanguophage|Gestat|Bioferrite|Overseer|Reformer|Growth|Autofeed|Lactat|Crib|"
                     r"Toxic|Biosculpt|Deathless|Hemopump|Fertility|IVF|Insemin|Vat|Birth")
UI_PARENTS = re.compile(r"Gizmo|FloatMenu|GetOptions|FillTab|DoWindowContents|DoTab|ProcessInput|Draw|Button|Options|"
                        r"Select|OnGUI|Menu|Choices|Option_")
READONLY = re.compile(r"\.get_|^Find\.|^Translator|^Messages\.|^SoundStarter|^Log\.|String\.|GenText|NamedArgument|"
                      r"op_|Enumerator|MoveNext|Dispose|^WindowStack\.Add$|Mathf\.|^Widgets\.|^Find$|ColoredText|"
                      r"ToStringPercent|Formatted|CameraJumper|^TutorSystem|Contains$|\.Any$|Where$|Select$|ToList$|"
                      r"FirstOrDefault$|TryGetComp$|GetComp$|^Enumerable\.|^GenCollection\.|Concat$|Named$|Translate$")

ROOT = lc.ROOT
src = []
for dp, _, fs in os.walk(os.path.join(ROOT, "Source/Client")):
    src += [open(os.path.join(dp, f), encoding="utf-8").read() for f in fs if f.endswith(".cs")]
src = "\n".join(src)

def tm(m):
    return (m.group(1).split(".")[-1], (m.group(2) or m.group(3)).split(".")[-1])

registered_methods = {tm(m) for m in re.finditer(
    r"SyncMethod\.Register\(\s*typeof\(([\w\.]+)\)\s*,\s*(?:nameof\(([\w\.]+)\)|\"(\w+)\")", src)}
patched_methods = {tm(m) for m in re.finditer(
    r"\[Mp(?:Prefix|Postfix|Transpiler)\(\s*typeof\(([\w\.]+)\)\s*,\s*(?:nameof\(([\w\.]+)\)|\"(\w+)\")", src)}
synced_fields = {m.group(2) or m.group(3) for m in re.finditer(
    r"Sync\.Field\(\s*typeof\(([\w\.]+)\)\s*,\s*(?:nameof\(([\w\.]+)\)|\"([\w\.\[\]/]+)\")", src)}
synced_fields = {f.split("/")[-1].split(".")[-1] for f in synced_fields}
by_ordinal = {(r["type"], r["meth"], r["ord"]) for r in lc.regs if not r.get("unparsed")}
covered_calls = {f"{t}.{m}" for t, m in registered_methods | patched_methods}

# Label context: strings near each lambda's ldftn site.
ctx = collections.defaultdict(list)
ldftn_re = re.compile(r"ldftn .*?'(<([^>]+)>b__(?:\d+_)?(\d+))'")
window = collections.deque(maxlen=30)
pending = []  # (key, lines_left)
with open(lc.IL, encoding="utf-8", errors="replace") as f:
    for line in f:
        s = lc.ldstr_re.search(line)
        dev = "DevGizmos" in line or "get_godMode" in line or "DevMode" in line
        if s or dev:
            tok = ("DEV" if dev else s.group(1))
            window.append(tok)
            for p in pending:
                ctx[p[0]].append(tok)
        pending = [(k, n - 1) for k, n in pending if n > 1]
        m = ldftn_re.search(line)
        if m:
            owner = line.split("::")[0].split()[-1].split(".")[-1].split("/")[0].strip("'")
            key = (m.group(2), int(m.group(3)), m.group(1))
            ctx[key] += list(window)[-6:]
            pending.append((key, 25))

out = collections.defaultdict(list)
for top, ls in lc.lambdas.items():
    if not BIOTECH.search(top):
        continue
    for l in ls:
        if not UI_PARENTS.search(l["parent"]):
            continue
        writes = [o for o in l["ops"] if o.startswith("=") and not o.startswith("=<>")]
        calls = [o for o in l["ops"] if "." in o and not o.startswith(("=", '"')) and not READONLY.search(o)]
        if not writes and not calls:
            continue
        if (top, l["parent"], l["ord"]) in by_ordinal:
            continue
        hit = [c for c in calls if c in covered_calls]
        name = f"<{l['parent']}>b__{(l['id'] + '_') if l['id'] else ''}{l['ord']}"
        labels = [t for t in ctx.get((l["parent"], l["ord"], name), []) if t]
        dev = "DEV" in labels or any(t.startswith("DEV") for t in labels)
        status = "covered-by-call" if hit else ("field-watch?" if writes and set(w[1:] for w in writes) & synced_fields else "GAP?")
        out[top].append((status, dev, l["parent"], l["ord"], name, writes, calls, hit, labels))

n = collections.Counter()
for top in sorted(out):
    print(f"== {top}")
    for status, dev, parent, ord_, name, writes, calls, hit, labels in sorted(out[top], key=lambda x: (x[2], x[3])):
        n[status + (" dev" if dev else "")] += 1
        lab = ", ".join(dict.fromkeys(t for t in labels if t != "DEV"))[:110]
        print(f"  {status:16} {'DEV ' if dev else '    '}{parent}[{ord_}]  labels: {lab}")
        print(f"      writes {', '.join(writes) or '-'} | calls {', '.join(calls[:6]) or '-'}" + (f" | covered via {', '.join(hit)}" if hit else ""))
print("\n" + ", ".join(f"{k}: {v}" for k, v in sorted(n.items())), file=sys.stderr)
