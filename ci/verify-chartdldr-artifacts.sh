#!/usr/bin/env bash
# Smoke-test chartdldr prebuilt archives: unpack in a clean dir and verify layout.
set -euo pipefail

ARTIFACT_ROOT="${1:-artifact}"

if [[ ! -d "$ARTIFACT_ROOT" ]]; then
  echo "Artifact directory not found: $ARTIFACT_ROOT" >&2
  exit 1
fi

mapfile -t ARCHIVES < <(
  find "$ARTIFACT_ROOT" -type f \( -name 'chartdldr_pi-*.zip' -o -name 'chartdldr_pi-*.tgz' \) | sort
)
if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
  echo "No chartdldr_pi-*.zip or chartdldr_pi-*.tgz files under ${ARTIFACT_ROOT}" >&2
  exit 1
fi

fail() {
  echo "verify-chartdldr: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_dir() {
  local path="$1"
  [[ -d "$path" ]] || fail "missing directory: $path"
}

extract_artifact() {
  local archive="$1"
  local dest="$2"
  if command -v unzip >/dev/null 2>&1 && unzip -t "$archive" >/dev/null 2>&1; then
    unzip -q "$archive" -d "$dest"
    return
  fi
  if tar -tf "$archive" >/dev/null 2>&1; then
    tar -xf "$archive" -C "$dest"
    return
  fi
  fail "cannot extract archive: ${archive}"
}

verify_macos_dylib() {
  local dylib="$1"
  if command -v lipo >/dev/null 2>&1; then
    local lipo_out
    lipo_out="$(lipo -info "$dylib" 2>&1)" || fail "lipo failed on macOS dylib"
    echo "$lipo_out" | grep -q 'x86_64' || fail "macOS dylib missing x86_64: $lipo_out"
    echo "$lipo_out" | grep -q 'arm64' || fail "macOS dylib missing arm64: $lipo_out"
  else
    local mach
    mach="$(file -b "$dylib")"
    echo "$mach" | grep -q 'x86_64' || fail "expected x86_64 in universal dylib, got: $mach"
    echo "$mach" | grep -q 'arm64' || fail "expected arm64 in universal dylib, got: $mach"
  fi
  if command -v otool >/dev/null 2>&1; then
    if otool -L "$dylib" | grep -qE '/opt/homebrew|/usr/local/Cellar'; then
      fail "macOS dylib links to Homebrew paths (not release-compatible)"
    fi
  elif strings "$dylib" 2>/dev/null | grep -qE '/opt/homebrew|/usr/local/Cellar'; then
    fail "macOS dylib links to Homebrew paths (not release-compatible)"
  fi
}

platform_from_archive() {
  local base="$1"
  case "$base" in
    *-linux-amd64.tgz) echo linux-amd64 ;;
    *-linux-arm64.tgz) echo linux-arm64 ;;
    *-windows.zip) echo windows ;;
    *-macos.zip) echo macos ;;
    *) echo unknown ;;
  esac
}

verify_archive() {
  local archive="$1"
  local platform
  platform="$(platform_from_archive "$(basename "$archive")")"
  [[ "$platform" != unknown ]] || fail "unrecognized archive name: $archive"

  local tmpdir staging
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  extract_artifact "$archive" "$tmpdir"
  staging="$(find "$tmpdir" -maxdepth 1 -type d -name 'chartdldr_pi-*' | head -1)"
  [[ -n "$staging" ]] || fail "no staging directory in $archive"

  echo "Verifying ${platform} ($(basename "$archive"))"

  case "$platform" in
    linux-amd64|linux-arm64)
      require_file "${staging}/lib/libchartdldr_pi.so"
      require_file "${staging}/install-chartdldr-linux.sh"
      require_file "${staging}/share/opencpn/plugins/chartdldr_pi/chart_sources.xml"
      local elf
      elf="$(file -b "${staging}/lib/libchartdldr_pi.so")"
      if [[ "$platform" == linux-amd64 ]]; then
        echo "$elf" | grep -qE 'ELF 64-bit.*x86-64' || fail "expected x86-64 ELF, got: $elf"
      else
        echo "$elf" | grep -qE 'ELF 64-bit.*aarch64|ARM aarch64' || fail "expected arm64 ELF, got: $elf"
      fi
      ;;
    windows)
      require_file "${staging}/plugins/chartdldr_pi.dll"
      require_file "${staging}/install-chartdldr-windows.bat"
      require_file "${staging}/plugins/chartdldr_pi/chart_sources.xml"
      ;;
    macos)
      require_file "${staging}/PlugIns/libchartdldr_pi.dylib"
      require_file "${staging}/install-chartdldr-macos.sh"
      require_file "${staging}/SharedSupport/plugins/chartdldr_pi/chart_sources.xml"
      verify_macos_dylib "${staging}/PlugIns/libchartdldr_pi.dylib"
      ;;
  esac

  require_file "${staging}/INSTALL.txt"
  grep -q '@CHARTDLDR_VERSION@' "${staging}/INSTALL.txt" && fail "INSTALL.txt still has placeholders"
  echo "  OK: ${platform}"
}

declare -A SEEN=()
for archive in "${ARCHIVES[@]}"; do
  platform="$(platform_from_archive "$(basename "$archive")")"
  verify_archive "$archive"
  SEEN["$platform"]=1
done

for required in linux-amd64 linux-arm64 windows macos; do
  [[ -n "${SEEN[$required]:-}" ]] || fail "missing artifact for platform: $required"
done

echo "All ${#ARCHIVES[@]} chartdldr artifacts verified."
