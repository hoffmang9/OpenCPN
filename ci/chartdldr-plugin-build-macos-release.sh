#!/usr/bin/env bash
# Build chartdldr_pi for drop-in use in the official OpenCPN macOS .app bundle.
# Uses the same universal wx deps bundle as ci/universal-build-macos.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
export DEPS_BUNDLE_REPO="${DEPS_BUNDLE_REPO:-https://dl.cloudsmith.io/public/nohal/opencpn-dependencies/raw/files}"
export DEPS_BUNDLE_FILE="${DEPS_BUNDLE_FILE:-macos_deps_universal-opencpn.tar.xz}"
export DEPS_BUNDLE_DEST="${DEPS_BUNDLE_DEST:-/usr/local}"
export ARCHS="${ARCHS:-arm64;x86_64}"
export INSTALL_PREFIX="${INSTALL_PREFIX:-/tmp/opencpn-chartdldr}"

for pkg in cmake gettext gpatch; do
  brew list --versions "${pkg}" >/dev/null 2>&1 || brew install "${pkg}"
done
# ShapefileCpp patches require GNU patch (same as ci/universal-build-macos.sh).
if [[ -d /opt/homebrew/opt/gpatch/libexec/gnubin ]]; then
  export PATH="/opt/homebrew/opt/gpatch/libexec/gnubin:${PATH}"
elif [[ -d /usr/local/opt/gpatch/libexec/gnubin ]]; then
  export PATH="/usr/local/opt/gpatch/libexec/gnubin:${PATH}"
fi

if [[ ! -f "/tmp/${DEPS_BUNDLE_FILE}" ]]; then
  curl -fsSL -o "/tmp/${DEPS_BUNDLE_FILE}" "${DEPS_BUNDLE_REPO}/${DEPS_BUNDLE_FILE}"
fi
sudo mkdir -p "${DEPS_BUNDLE_DEST}"
sudo tar -C "${DEPS_BUNDLE_DEST}" -xJf "/tmp/${DEPS_BUNDLE_FILE}"

rm -rf build
mkdir -p build
cd build

cmake -DOCPN_CI_BUILD=ON \
  -DOCPN_VERBOSE=OFF \
  -DOCPN_USE_LIBCPP=ON \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DOCPN_RELEASE=universal \
  -DOCPN_BUILD_TEST=OFF \
  -DOCPN_BUILD_SAMPLE=OFF \
  -DOCPN_USE_DEPS_BUNDLE=ON \
  -DCMAKE_OSX_ARCHITECTURES="${ARCHS}" \
  -DOCPN_USE_SYSTEM_LIBARCHIVE=OFF \
  -DOCPN_DEPS_BUNDLE_PATH="${DEPS_BUNDLE_DEST}" \
  -DwxWidgets_CONFIG_EXECUTABLE="${DEPS_BUNDLE_DEST}/lib/wx/config/osx_cocoa-unicode-3.2" \
  -DCMAKE_APPBUNDLE_PATH="${DEPS_BUNDLE_DEST}" \
  -DwxWidgets_CONFIG_OPTIONS="--prefix=${DEPS_BUNDLE_DEST}" \
  ..

# fixup_bundle install() expects all bundled plugin dylibs to exist.
# Main app target is OpenCPN on macOS (opencpn on Linux/Windows).
make -j"$(sysctl -n hw.physicalcpu)" OpenCPN chartdldr_pi dashboard_pi grib_pi wmm_pi

cmake --install . --prefix "${INSTALL_PREFIX}"

PLUGIN=""
for candidate in \
  "${INSTALL_PREFIX}/bin/OpenCPN.app/Contents/PlugIns/libchartdldr_pi.dylib" \
  "${INSTALL_PREFIX}/bin/OpenCPN.app/Contents/Plugins/libchartdldr_pi.dylib" \
  "${ROOT}/build/plugins/chartdldr_pi/libchartdldr_pi.dylib"; do
  if [[ -f "$candidate" ]]; then
    PLUGIN="$candidate"
    break
  fi
done

if [[ -z "$PLUGIN" ]]; then
  echo "chartdldr_pi.dylib not found after install" >&2
  exit 1
fi

"${ROOT}/ci/chartdldr-fixup-macos-plugin.sh" "$PLUGIN"

mkdir -p "${ROOT}/build/plugins/chartdldr_pi"
cp "$PLUGIN" "${ROOT}/build/plugins/chartdldr_pi/libchartdldr_pi.dylib"
echo "Release-compatible dylib: ${ROOT}/build/plugins/chartdldr_pi/libchartdldr_pi.dylib"
