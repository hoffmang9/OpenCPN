#!/usr/bin/env bash
# Legacy Homebrew deps (not ABI-compatible with release OpenCPN.app).
# CI uses ci/chartdldr-plugin-build-macos-release.sh instead.
set -euo pipefail

here="$(cd "$(dirname "$0")"; pwd)"

brew list --versions python3 >/dev/null 2>&1 || brew update-reset || true

for pkg in $(sed '/#/d' < "${here}/macos-deps"); do
  brew list --versions "${pkg}" >/dev/null 2>&1 || brew install "${pkg}" || brew install "${pkg}"
  brew link --overwrite "${pkg}" >/dev/null 2>&1 || true
done

for pkg in wxwidgets@3.2 lz4 xz zstd gpatch; do
  brew list --versions "${pkg}" >/dev/null 2>&1 || brew install "${pkg}"
done

for prefix in /opt/homebrew /usr/local; do
  if [[ -d "${prefix}/include" && -d "${prefix}/opt/libarchive/include" ]]; then
    ln -sf "${prefix}/opt/libarchive/include/archive.h" "${prefix}/include/archive.h"
    ln -sf "${prefix}/opt/libarchive/include/archive_entry.h" "${prefix}/include/archive_entry.h"
  fi
  if [[ -f "${prefix}/opt/libarchive/lib/libarchive.13.dylib" && -d "${prefix}/lib" ]]; then
    ln -sf "${prefix}/opt/libarchive/lib/libarchive.13.dylib" "${prefix}/lib/libarchive.13.dylib"
  fi
done
