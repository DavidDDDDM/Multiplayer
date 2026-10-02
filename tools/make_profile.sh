#!/bin/bash
# Create (or reset the mod list of) an isolated RimWorld profile: Prepatcher, Harmony, Core, Biotech, Multiplayer only.
set -euo pipefail
DATA="${1:?profile dir}"
mkdir -p "$DATA/Config"
cat > "$DATA/Config/ModsConfig.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<ModsConfigData>
  <version>1.6.4871 rev600</version>
  <activeMods>
    <li>zetrith.prepatcher</li>
    <li>brrainz.harmony</li>
    <li>ludeon.rimworld</li>
    <li>ludeon.rimworld.biotech</li>
    <li>rwmt.multiplayer</li>
  </activeMods>
  <knownExpansions>
    <li>ludeon.rimworld.royalty</li>
    <li>ludeon.rimworld.ideology</li>
    <li>ludeon.rimworld.biotech</li>
    <li>ludeon.rimworld.anomaly</li>
    <li>ludeon.rimworld.odyssey</li>
  </knownExpansions>
</ModsConfigData>
XML
