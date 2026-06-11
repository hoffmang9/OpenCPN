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
    echo "On macOS use ci/chartdldr-plugin-build-macos-release.sh for release .app-compatible builds." >&2
    exit 1
    ;;
  *)
    echo "Unsupported host for chartdldr-plugin-build.sh: $(uname -s)" >&2
    exit 1
    ;;
esac
