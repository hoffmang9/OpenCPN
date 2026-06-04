#!/usr/bin/env bash
# Configure OpenCPN and build only the chartdldr_pi target (plus deps).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_TYPE="${BUILD_TYPE:-Release}"
mkdir -p build
cd build

case "$(uname -s)" in
  Linux)
    cmake -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
      -DOCPN_CI_BUILD=ON \
      -DOCPN_BUILD_TEST=OFF \
      ..
    cmake --build . --target chartdldr_pi -j "$(nproc)"
    ;;
  Darwin)
    cmake -DOCPN_CI_BUILD=ON \
      -DOCPN_VERBOSE=OFF \
      -DOCPN_USE_SYSTEM_LIBARCHIVE=OFF \
      -DCMAKE_INSTALL_PREFIX=/tmp/opencpn \
      -DOCPN_RELEASE=0 \
      -DOCPN_BUILD_TEST=OFF \
      -DOCPN_BUILD_SAMPLE=OFF \
      ..
    make chartdldr_pi -j "$(sysctl -n hw.physicalcpu 2>/dev/null || echo 2)"
    ;;
  *)
    echo "Unsupported host for chartdldr-plugin-build.sh: $(uname -s)" >&2
    exit 1
    ;;
esac
