#!/bin/bash
# Create (or reset the mod list of) an isolated RimWorld profile: Prepatcher, Harmony, Core, Biotech, Multiplayer only.
set -euo pipefail
MP_MOD="${MP_MOD:-rwmt.multiplayer}"   # rwmt.multiplayer_steam = the Workshop pinned copy (match a host running it)
DATA="${1:?profile dir}"
mkdir -p "$DATA/Config"
cat > "$DATA/Config/ModsConfig.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<ModsConfigData>
  <version>1.6.4871 rev600</version>
  <activeMods>
    <li>zetrith.prepatcher</li>
    <li>brrainz.harmony</li>
    <li>ludeon.rimworld</li>
    <li>ludeon.rimworld.biotech</li>
    <li>$MP_MOD</li>
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
