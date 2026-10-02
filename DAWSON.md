# dawson/stable: private hardening fork of rwmt Multiplayer

Branch `dawson/stable` = upstream `continuous` (ea633b8, 2026-08-01) + local test tooling in `tools/`.
Purpose: a stable shared-colony build (Core + Biotech only) for two friends (Linux host, Windows client).

- Build: `tools/build.sh` (needs the .NET 10 SDK at `~/.dotnet10`) → `dist/Multiplayer`
- Launch an isolated profile: `tools/rw.sh test` (Steam must be running)
- Determinism check: `tools/replay_check.sh <replay> <ticks>`

Full handoff, roadmap and test instructions live in the owner's private project repo:
`~/rimworld-companion/docs/MP_HANDOFF.md`, `MP_ROADMAP.md`, `MP_TESTING.md`.
