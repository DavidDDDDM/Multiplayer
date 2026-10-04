# pinned/: overlay that turns `dist/Multiplayer` into our Friends-only Workshop build
Applied by `tools/build.sh` after every build:
- drops upstream's `About/PublishedFileId.txt` (2606448745 = the OFFICIAL rwmt item; uploading with it would target their page)
- renames the mod "Multiplayer (Dawson pinned)" (packageId stays `rwmt.Multiplayer`; MP's code expects it)
- copies `PublishedFileId.txt` from here once our own Workshop item exists
- copies `FriendTest/` (friend's T4 kit) plus `~/rw-mp-test/MpReplays/baseline-01.zip` (NOT committed: the fork is
  public and the replay is a private colony)
Upload: owner, normal game, dev mode → Mods → "Multiplayer (Dawson pinned)" → Upload → set Friends-only.
