# Biotech sync-coverage audit (M3), static pass, 2026-10-02

Game build **1.6.4871 rev600**, fork `dawson/stable` (upstream continuous `ea633b8`). Scope: Core + Biotech, the only
content our shared colony uses. This is the static half of M3; the runtime half (`-printsync` → `SyncHandlers.xml`)
is still to do (it needs a game launch on the test profile).

## Method (re-runnable after every game update)
1. `ilspycmd -il -r <Managed> <Managed>/Assembly-CSharp.dll > audit/decomp/acs.il` (also `-p -o audit/decomp/acs`
   for readable C#). `audit/decomp/` is local-only (`.git/info/exclude`): decompiled game code is never committed.
2. `audit/lambda_check.py > audit/lambda_check.txt`: for every `SyncMethod/SyncDelegate.Lambda(type, method, N)`
   registration, resolves lambda N (`<Method>b__N` / `<Method>b__{id}_N`) in the **installed** game IL and prints
   what it calls and writes, next to MP's comment.
3. `audit/biotech_gaps.py > audit/biotech_gaps.txt`: every lambda in a Biotech-named type, inside a UI method
   (gizmos, float menus, tabs, dialogs), that writes a field or calls a non-getter, and is **not** covered by an
   ordinal registration, a `SyncMethod.Register`, an `[MpPrefix/Postfix]` or a `Sync.Field` watch.
4. Two ad-hoc IL passes (same scripts' parsers): method-group gizmo actions (`action = Foo`), and `ref`-field widget
   edits (`Widgets.Checkbox(ref x)`, sliders, text fields) in Biotech UI.
5. Each remaining candidate was traced by hand in the decompiled source / MP source.

## Result 1: lambda ordinals did not drift on 1.6.4871
All **318** ordinal registrations resolve, and every one's body matches its comment (e.g. `Building_GrowthVat.GetGizmos[6]
// Cancel load` → `DestroyEmbryo, TryDropAll, EndCurrentJob`; `MechanitorControlGroupGizmo.GetWorkModeOptions[1]` →
`MechanitorControlGroup.SetWorkMode`). A misaligned ordinal would silently sync the wrong button, so this is the check
to rerun first after any RimWorld update (M7). Not covered by the script: the 4 `MultiplayerAPIBridge` passthroughs
(only used by compat mods; we run none) and one constructor-lambda (`ColonistBar.Entry`, non-Biotech).

## Result 2: Biotech coverage table
| Area | Player action | Status | How MP covers it |
|---|---|---|---|
| Mechanitor | Control groups: assign, work mode, mech colour | Synced | `Designator_MechControlGroup.ProcessInput[1]`, `GetWorkModeOptions[1]`, `PawnColumnWorker_ControlGroup[0]`, `MainTabWindow_Mechs[0]` |
| Mechanitor | Select overseer / select all mechs / bandwidth + group gizmo tooltips | UI-only | selection & drawing only |
| Mechanitor | Disconnect mech, auto-repair toggle, carrier spawn + autofill slider | Synced | `ForceDisconnectMechFromOverseer`, `CompMechRepairable[1]`, `CompMechCarrier.TrySpawnPawns`, `MechCarrierGizmo` prefix |
| Mechanitor | Gestator bills, recharger | Synced | generic bill sync; recharger has no non-dev player action |
| Mechanitor | Boss call (`Command_CallBossgroup`) | Synced | ends in `CompUsable.TryStartUseJob` → `TryTakeOrderedJob` (globally synced) |
| Mechanitor | Band node tune-to | Synced | `CompBandNode[7]` |
| Genes | Gene assembler start/reset, extractor select pawn/cancel | Synced | `Building_GeneAssembler.Start/Reset`, `Building_GeneExtractor.SelectPawn[0]`, `GetGizmos[2]`, `Cancel` |
| Genes | Xenogerm dialog (pick packs, name, icon) | UI-only | dialog-local state; the final **Start** is synced |
| Genes | Eject genepack from bank in that dialog | Synced | `Dialog_CreateXenogerm.DrawGenepack[8]` |
| Genes | Genebank "allow all" checkbox, per-pack load/unload, genepack auto-load | Synced | `Sync.Field(CompGenepackContainer.autoLoad)` watched in `DoItemsLists`; `DoRow` pre/postfix; `Genepack.GetGizmos[1]` |
| Genes | Implant xenogerm (target pawn, cancel) | Synced | `Xenogerm.SetTargetPawn[1]`, `Xenogerm.GetGizmos[2]` |
| Genes | Reimplant xenogerm ability | Synced | `GeneUtility.GiveReimplantJob` → `TryTakeOrderedJob` |
| Genes | Deathrest wake, auto-wake | Synced | `Gene_Deathrest.Wake`, `GetGizmos[2]` |
| Genes | Hemogen pack allowed toggle, hemogen target slider | Synced | `Sync.Field(Gene_Hemogen.hemogenPacksAllowed)`, `Gizmo_Slider` prefix |
| Genes | Save / delete **custom xenogerm template** | **Gap (low)** | `CustomXenogermUtility` → `Find.CustomXenogermDatabase.Add/Remove` is unsynced; see G1 |
| Children | Pregnancy, labor, birth | Synced / sim | no player action except dev gizmos (synced, dev-only) |
| Children | Name newborn (letter → rename) | Synced | `Pawn.Name` setter synced + baby-name special case (`SyncDelegates.cs:409`) |
| Children | Baby → child letter (colonist / slave) | Synced | `ChoiceLetter_BabyToChild.ChoseColonist/ChoseSlave` |
| Children | Growth moment choice | Synced | `ChoiceLetter_GrowthMoment.MakeChoices` + `GrowthMomentSession` |
| Children | Autofeed setting, baby food allowed | Synced | `Pawn_MindState.SetAutofeeder`, `SetBabyFoodAllowed` prefix |
| Children | Embryo/ovum implant target, cancel | Synced | `HumanEmbryo.CanImplantFloatOption[1]`, `GetGizmos[2]`, `HumanOvum.GetGizmos[1]` |
| Children | Growth vat: select embryo, cancel growth, cancel load, enter | Synced | `SelectEmbryo`, `GetGizmos[1]/[6]`, `Building_Enterable.SelectPawn` |
| Pollution | Toxifier, pollution pump, atomizer auto-load/eject | Synced | sim-side; player toggles `CompAtomizer[1]`, `EjectContents` |
| Other | Subcore scanner init / eject | Synced | `GetGizmos[1]`, `EjectContents` |

Dev-mode-only gizmos (host-only during tests) are mostly registered with `SetDebugOnly`. Some dev *sub-menus*
(e.g. `GeneUIUtility.DoDebugButton[1..3,6,8..10]`, `Gene_Deathrest.GetGizmos[4]`, `CompMechGestatorTank[0..1]`) are
reported by the script as unregistered, but they only build menus whose inner actions are the registered ones.
Rule anyway: **in MP, only the host uses dev tools, and only for setup.**

## Gaps
- **G1 (low): custom xenogerm templates aren't synced.** Saving a template in the gene-assembler dialog, or deleting one
  in "Load", only changes the clicking player's `Game.customXenogermDatabase`. That isn't read by the simulation, so
  it shouldn't cause a Rand/state desync. But the two players' template lists diverge, and a client's templates are
  lost on the next join-point (the host's save wins). **Repro for M4:** client saves a template, host opens Load →
  not there. **Play rule until fixed:** only the host saves xenogerm templates. Fix candidate: `SyncMethod.Register`
  for `CustomXenogermDatabase.Add/Remove` (needs a sync worker for `CustomXenogerm`, or sync the dialog's accept).

No other Biotech gameplay gap was found statically.

## What a static pass can't see (left for M4 soak + `-printsync`)
- Rand use / iteration-order differences in **simulation** code (the main source of desyncs) aren't UI-sync issues. Only
  the soak + desync traces find those.
- UI actions in types whose names don't match the Biotech keyword list, and actions done through `Find.WindowStack`
  dialogs built elsewhere.
- Runtime confirmation that each listed handler is actually registered (`-printsync` → `SyncHandlers.xml`).
