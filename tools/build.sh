#!/bin/bash
# Build Multiplayer and bundle a RimWorld 1.6-only mod folder into dist/Multiplayer.
# Usage: tools/build.sh [--local-refs]   (--local-refs compiles against the installed game's DLLs; needs the
#        local-only Source/Directory.Build.targets)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${RIMWORLD_DIR:-$HOME/.steam/debian-installation/steamapps/common/RimWorld}"
export DOTNET_ROOT="${DOTNET_ROOT_MP:-$HOME/.dotnet10}"   # SourceGen needs Roslyn 5.x (.NET 10 SDK)
EXTRA=()
[[ "${1:-}" == "--local-refs" ]] && EXTRA+=("-p:LocalRimRefs=$GAME/RimWorldLinux_Data/Managed")

cd "$ROOT"
git submodule update --init --recursive
"$DOTNET_ROOT/dotnet" build Source/Multiplayer.sln -c Release "${EXTRA[@]}" -nologo -v q

VERSION=$(grep -Po '(?<=SimpleVersion = ")[0-9\.]+' Source/Common/Version.cs)
FULL="${VERSION} ($(git rev-parse --short HEAD)$(git diff --quiet HEAD -- Source || echo '-dirty'))"
OUT="$ROOT/dist/Multiplayer"
rm -rf "$OUT" && mkdir -p "$OUT/1.6"
cp -r About Textures "$OUT/"
cat > "$OUT/LoadFolders.xml" <<'XML'
<loadFolders>
  <v1.6>
    <li>/</li>
    <li>1.6</li>
  </v1.6>
</loadFolders>
XML
sed -i "s|<modVersion>.*</modVersion>.*\$|<modVersion>${FULL}</modVersion>|" "$OUT/About/About.xml"
cp -r Assemblies AssembliesCustom Defs Languages "$OUT/1.6/"
rm -f "$OUT/1.6/Languages/.git" "$OUT/1.6/Languages/LICENSE" "$OUT/1.6/Languages/README.md"
echo "Built Multiplayer $FULL -> $OUT"
