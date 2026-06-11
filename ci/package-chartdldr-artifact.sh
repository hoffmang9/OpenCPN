#!/usr/bin/env bash
# Package chartdldr_pi library + data for GitHub Release artifacts.
set -euo pipefail

usage() {
  echo "Usage: $0 <linux-amd64|linux-arm64|windows|macos> [version]" >&2
  exit 1
}

PLATFORM="${1:-}"
VERSION="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "$PLATFORM" ]]; then
  usage
fi

chartdldr_cmake_version() {
  local maj min pat
  maj=$(grep 'set(VERSION_MAJOR' plugins/chartdldr_pi/CMakeLists.txt | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
  min=$(grep 'set(VERSION_MINOR' plugins/chartdldr_pi/CMakeLists.txt | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
  pat=$(grep 'set(VERSION_PATCH' plugins/chartdldr_pi/CMakeLists.txt | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
  echo "${maj}.${min}.${pat}"
}

if [[ -z "$VERSION" ]]; then
  VERSION="$(chartdldr_cmake_version)"
fi

GIT_SHA="${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
STAGING="chartdldr_pi-${VERSION}-${PLATFORM}"
ARTIFACT_DIR="${ROOT}/artifact"
rm -rf "${ARTIFACT_DIR}/${STAGING}"
mkdir -p "${ARTIFACT_DIR}"

case "$PLATFORM" in
  linux-amd64|linux-arm64)
    LIB_SRC="${ROOT}/build/plugins/chartdldr_pi/libchartdldr_pi.so"
    LIB_DST="lib/libchartdldr_pi.so"
    DATA_PREFIX="share/opencpn/plugins/chartdldr_pi"
    ;;
  macos)
    LIB_SRC=""
    for candidate in \
      "${ROOT}/build/plugins/chartdldr_pi/libchartdldr_pi.dylib" \
      "/tmp/opencpn-chartdldr/bin/OpenCPN.app/Contents/PlugIns/libchartdldr_pi.dylib" \
      "/tmp/opencpn-chartdldr/bin/OpenCPN.app/Contents/Plugins/libchartdldr_pi.dylib"; do
      if [[ -f "$candidate" ]]; then
        LIB_SRC="$candidate"
        break
      fi
    done
    LIB_DST="PlugIns/libchartdldr_pi.dylib"
    DATA_PREFIX="SharedSupport/plugins/chartdldr_pi"
    ;;
  windows)
    LIB_SRC=""
    for candidate in \
      "${ROOT}/build/plugins/chartdldr_pi/Release/chartdldr_pi.dll" \
      "${ROOT}/build/Release/plugins/chartdldr_pi.dll" \
      "${ROOT}/build/${CONFIGURATION:-Release}/plugins/chartdldr_pi.dll"; do
      if [[ -f "$candidate" ]]; then
        LIB_SRC="$candidate"
        break
      fi
    done
    if [[ -z "$LIB_SRC" ]]; then
      LIB_SRC="$(find "${ROOT}/build" -name 'chartdldr_pi.dll' -type f 2>/dev/null | head -1 || true)"
    fi
    LIB_DST="plugins/chartdldr_pi.dll"
    DATA_PREFIX="plugins/chartdldr_pi"
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    exit 1
    ;;
esac

if [[ -z "${LIB_SRC:-}" || ! -f "$LIB_SRC" ]]; then
  echo "Plugin library not found for platform ${PLATFORM}" >&2
  exit 1
fi

STAGE_ROOT="${ARTIFACT_DIR}/${STAGING}"
mkdir -p "$(dirname "${STAGE_ROOT}/${LIB_DST}")"
cp "$LIB_SRC" "${STAGE_ROOT}/${LIB_DST}"
mkdir -p "${STAGE_ROOT}/${DATA_PREFIX}"
cp -R "${ROOT}/plugins/chartdldr_pi/data/." "${STAGE_ROOT}/${DATA_PREFIX}/"
if compgen -G "${ROOT}/build/plugins/chartdldr_pi/*.mo" > /dev/null; then
  cp "${ROOT}/build/plugins/chartdldr_pi/"*.mo "${STAGE_ROOT}/${DATA_PREFIX}/" || true
fi

INSTALL_TXT="${STAGE_ROOT}/INSTALL.txt"
sed -e "s/@CHARTDLDR_VERSION@/${VERSION}/g" \
    -e "s/@GIT_SHA@/${GIT_SHA}/g" \
    "${ROOT}/ci/chartdldr-prebuilt-INSTALL.txt" > "${INSTALL_TXT}"

case "$PLATFORM" in
  macos)
    install_script="${ROOT}/ci/install-chartdldr-macos.sh"
    ;;
  linux-amd64|linux-arm64)
    install_script="${ROOT}/ci/install-chartdldr-linux.sh"
    ;;
  windows)
    install_script="${ROOT}/ci/install-chartdldr-windows.bat"
    ;;
esac
if [[ -n "${install_script:-}" && -f "$install_script" ]]; then
  cp "$install_script" "${STAGE_ROOT}/$(basename "$install_script")"
  chmod +x "${STAGE_ROOT}/$(basename "$install_script")" 2>/dev/null || true
fi

chartdldr_create_tgz() {
  local dir="$1"
  local tgzfile="$2"
  local base name
  base="$(dirname "$dir")"
  name="$(basename "$dir")"
  rm -f "$tgzfile"
  tar -czf "$tgzfile" -C "$base" "$name"
}

chartdldr_create_zip() {
  local dir="$1"
  local zipfile="$2"
  local base name
  base="$(dirname "$dir")"
  name="$(basename "$dir")"

  if command -v zip >/dev/null 2>&1; then
    (cd "$base" && zip -qr "$zipfile" "$name")
    return
  fi

  # GitHub windows-2022 runners lack zip(1) in bash; bsdtar is available.
  if tar --version >/dev/null 2>&1; then
    rm -f "$zipfile"
    tar -a -c -f "$zipfile" -C "$base" "$name"
    return
  fi

  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "Compress-Archive -Path '${dir}' -DestinationPath '${zipfile}' -Force"
    return
  fi

  echo "No zip, tar, or powershell available to create ${zipfile}" >&2
  exit 1
}

case "$PLATFORM" in
  linux-amd64|linux-arm64)
    ARCHIVE_PATH="${ARTIFACT_DIR}/${STAGING}.tgz"
    chartdldr_create_tgz "${STAGE_ROOT}" "${ARCHIVE_PATH}"
    ;;
  *)
    ARCHIVE_PATH="${ARTIFACT_DIR}/${STAGING}.zip"
    rm -f "${ARCHIVE_PATH}"
    chartdldr_create_zip "${STAGE_ROOT}" "${ARCHIVE_PATH}"
    ;;
esac

echo "Created ${ARCHIVE_PATH}"
