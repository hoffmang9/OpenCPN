#!/usr/bin/env bash
# Install chartdldr_pi from an unzipped macOS release artifact.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OCPN_APP="${1:-/Applications/OpenCPN.app}"

LIB_SRC="${SCRIPT_DIR}/PlugIns/libchartdldr_pi.dylib"
DATA_SRC="${SCRIPT_DIR}/SharedSupport/plugins/chartdldr_pi"

if [[ ! -f "$LIB_SRC" ]]; then
  die "missing ${LIB_SRC} — run this script from the unzipped macOS artifact folder"
fi
if [[ ! -d "$DATA_SRC" ]]; then
  die "missing ${DATA_SRC}"
fi
if [[ ! -d "$OCPN_APP/Contents" ]]; then
  die "OpenCPN.app not found at: ${OCPN_APP} (pass path as first argument)"
fi

if pgrep -x OpenCPN >/dev/null 2>&1; then
  die "OpenCPN is running — quit it completely, then run this script again"
fi

PLUGIN_DST="${OCPN_APP}/Contents/PlugIns/libchartdldr_pi.dylib"
DATA_DST="${OCPN_APP}/Contents/SharedSupport/plugins/chartdldr_pi"

if [[ -f "$PLUGIN_DST" ]]; then
  backup="${PLUGIN_DST}.bak.$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing plugin to ${backup}"
  cp -p "$PLUGIN_DST" "$backup"
fi

mkdir -p "$(dirname "$PLUGIN_DST")" "$DATA_DST"
cp -p "$LIB_SRC" "$PLUGIN_DST"
cp -R "${DATA_SRC}/." "$DATA_DST/"

if otool -L "$PLUGIN_DST" 2>/dev/null | grep -q /opt/homebrew/opt/wxwidgets; then
  echo "warning: plugin still links to Homebrew wx — use a release-built macOS zip, not an old artifact"
fi

if command -v lipo >/dev/null 2>&1; then
  echo "Architecture: $(lipo -info "$PLUGIN_DST" 2>/dev/null || file "$PLUGIN_DST")"
fi

echo "Installed chartdldr_pi into ${OCPN_APP}"
echo "Start OpenCPN and enable Chart Downloader under Options → Plugins."
