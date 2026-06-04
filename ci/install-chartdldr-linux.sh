#!/usr/bin/env bash
# Install chartdldr_pi from an unzipped Linux release artifact (user plugin paths).
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

LIB_SRC="${SCRIPT_DIR}/lib/libchartdldr_pi.so"
DATA_SRC="${SCRIPT_DIR}/share/opencpn/plugins/chartdldr_pi"

if [[ -z "${HOME:-}" ]]; then
  die "HOME is not set"
fi
if [[ -f "/.flatpak-info" ]] || [[ -d "${HOME}/.var/app/org.opencpn.OpenCPN" ]]; then
  die "Flatpak OpenCPN detected — these binaries are not compatible; build from source instead"
fi
if [[ ! -f "$LIB_SRC" ]]; then
  die "missing ${LIB_SRC} — run this script from the unzipped Linux artifact folder"
fi
if [[ ! -d "$DATA_SRC" ]]; then
  die "missing ${DATA_SRC}"
fi

if pgrep -x opencpn >/dev/null 2>&1; then
  die "opencpn is running — quit OpenCPN, then run this script again"
fi

LIB_DST="${HOME}/.local/lib/opencpn/plugins/libchartdldr_pi.so"
DATA_DST="${HOME}/.local/share/opencpn/plugins/chartdldr_pi"

if [[ -f "$LIB_DST" ]]; then
  backup="${LIB_DST}.bak.$(date +%Y%m%d%H%M%S)"
  echo "Backing up existing plugin to ${backup}"
  cp -p "$LIB_DST" "$backup"
fi

mkdir -p "$(dirname "$LIB_DST")" "$DATA_DST"
cp -p "$LIB_SRC" "$LIB_DST"
cp -R "${DATA_SRC}/." "$DATA_DST/"

echo "Installed chartdldr_pi for user $(whoami)"
echo "  library: ${LIB_DST}"
echo "  data:    ${DATA_DST}"
echo ""
echo "Works with distro/self-built OpenCPN using wxGTK 3.2, not Flatpak/Snap."
echo "If a system-packaged chartdldr remains enabled, disable the bundled copy in"
echo "Options → Plugins and use this user-installed build."
