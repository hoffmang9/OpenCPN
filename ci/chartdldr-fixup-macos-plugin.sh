#!/usr/bin/env bash
# Normalize wxWidgets install names on a chartdldr_pi dylib (upstream release style).
set -euo pipefail

PLUGIN="${1:?plugin dylib path required}"

if [[ ! -f "$PLUGIN" ]]; then
  echo "Plugin not found: $PLUGIN" >&2
  exit 1
fi

while IFS= read -r lib; do
  [[ -z "$lib" ]] && continue
  newlib="$(echo "$lib" | sed 's/-3\.2.*\.dylib/-3.2.dylib/g')"
  if [[ "$lib" != "$newlib" ]]; then
    install_name_tool -change "$lib" "$newlib" "$PLUGIN"
  fi
done < <(otool -L "$PLUGIN" | grep libwx | awk '{print $1}')

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$PLUGIN"
fi

echo "Fixed plugin: $PLUGIN"
lipo -info "$PLUGIN" 2>/dev/null || file "$PLUGIN"
