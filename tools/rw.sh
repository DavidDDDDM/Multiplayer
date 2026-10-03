#!/bin/bash
# Launch RimWorld with an isolated profile (own saves, config, mod list) so the real profile is never touched.
# Usage: tools/rw.sh <profile> [extra RimWorld args...]    profile dir = ~/rw-mp-<profile>
# Examples: tools/rw.sh test                       (host, username Dawson)
#           tools/rw.sh test2 -username=Player2    (second local client)
#           tools/rw.sh test -replay=a:baseline-01:60000:60 -replaydata=/tmp/out
set -euo pipefail
PROFILE="${1:?profile name}"; shift
GAME="${RIMWORLD_DIR:-$HOME/.steam/debian-installation/steamapps/common/RimWorld}"
DATA="$HOME/rw-mp-$PROFILE"
"$(dirname "$0")/make_profile.sh" "$DATA"
ARGS=("-savedatafolder=$DATA" "-logfile" "$DATA/Player.log")
[[ " $* " == *" -username="* ]] || ARGS+=("-username=Dawson")
for a in "$@"; do   # MP rejects names outside 3..15 chars (MultiplayerServer.Min/MaxUsernameLength) only at connect time
  if [[ "$a" == -username=* ]]; then u="${a#-username=}"; (( ${#u} >= 3 && ${#u} <= 15 )) || { echo "!! username '$u' must be 3-15 chars"; exit 2; }; fi
done
cd "$GAME"
exec ./RimWorldLinux "${ARGS[@]}" "$@"
