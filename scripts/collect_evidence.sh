#!/bin/zsh
# Collects static reverse-engineering evidence about Apple's Calendar.app with REA.
# Read-only: never modifies Calendar.app or the user's calendar data.
set -u
ROOT="${0:A:h:h}"
REA="$ROOT/tools/node_modules/.bin/rea"
APP=/System/Applications/Calendar.app
RES="$APP/Contents/Resources"
OUT="$ROOT/evidence/rea"
mkdir -p "$OUT"

run() { local name=$1; shift; "$REA" "$@" --format json > "$OUT/$name.json" 2>&1; echo "$name exit=$?"; }

"$REA" --version > "$OUT/rea-version.txt"
"$REA" doctor --format json > "$OUT/rea-doctor.json" 2>&1
run inspect-plist            inspect-plist "$APP"
run inspect-signature        inspect-signature "$APP"
run inspect-macho            inspect-macho "$APP/Contents/MacOS/Calendar"
run decode-interface-builder decode-interface-builder "$APP"
run inspect-asset-catalog    inspect-asset-catalog "$RES/Assets.car"   # expected to fail: .car unsupported

# Fallbacks with Apple's own tools for formats REA does not decode
xcrun assetutil --info "$RES/Assets.car" > "$OUT/assetutil-Assets.json" 2>&1
for f in MainMenu Localizable PreferencesPanel GoToDay ContextualMenus; do
  plutil -convert json -o "$OUT/$f.loctable.json" "$RES/$f.loctable"
done
cp "$RES/iCal.sdef" "$OUT/iCal.sdef"
shasum -a 256 "$APP/Contents/MacOS/Calendar" "$APP/Contents/Info.plist" "$RES/Assets.car" > "$OUT/target-digests.txt"

python3 -I "$ROOT/scripts/summarize_evidence.py" "$OUT"
