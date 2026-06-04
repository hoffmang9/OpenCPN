#!/usr/bin/env bash
# Run platform install scripts against a fake OpenCPN tree; assert files land correctly.
set -euo pipefail

PLATFORM="${1:-}"
ARTIFACT_ROOT="${2:-artifacts}"

usage() {
  echo "Usage: $0 <linux|macos|windows> [artifact_root]" >&2
  exit 1
}

fail() {
  echo "verify-chartdldr-install: $*" >&2
  exit 1
}

[[ -n "$PLATFORM" ]] || usage

to_slash() {
  printf '%s' "${1//\\//}"
}

# pwd -W often ends with '\' which breaks cmd quoting: cd /d "D:\path\"
win_path() {
  local p
  p="$(cd "$1" && pwd -W | tr -d '\r\n')"
  p="${p%/}"
  p="${p%\\}"
  printf '%s' "$p"
}

find_platform_zip() {
  local pattern="$1"
  local zip
  zip="$(find "$ARTIFACT_ROOT" -type f -name "$pattern" 2>/dev/null | head -1)"
  [[ -n "$zip" && -f "$zip" ]] || fail "no zip matching ${pattern} under ${ARTIFACT_ROOT}"
  echo "$zip"
}

extract_artifact() {
  local archive="$1"
  local dest="$2"
  archive="$(to_slash "$archive")"
  dest="$(to_slash "$dest")"
  mkdir -p "$dest"
  # Windows CI builds use bsdtar -a (.zip extension, not always unzip-friendly).
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

find_staging_dir() {
  local root="$1"
  local staging
  staging="$(find "$root" -maxdepth 1 -type d -name 'chartdldr_pi-*' | head -1)"
  [[ -n "$staging" ]] || fail "no chartdldr_pi-* folder in ${root}"
  echo "$staging"
}

assert_same_file() {
  local a="$1"
  local b="$2"
  [[ -f "$a" && -f "$b" ]] || fail "missing file for compare: $a or $b"
  if cmp -s "$a" "$b" 2>/dev/null; then
    return
  fi
  local ha hb
  ha="$(sha256sum "$a" | awk '{print $1}')"
  hb="$(sha256sum "$b" | awk '{print $1}')"
  if [[ "$ha" == "$hb" ]]; then
    return
  fi
  fail "installed file differs from artifact (sizes $(wc -c <"$a") vs $(wc -c <"$b")): $b"
}

verify_macos() {
  (
    set -euo pipefail
    local zip staging tmpdir fake_app
    zip="$(find_platform_zip 'chartdldr_pi-*-macos.zip')"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    extract_artifact "$zip" "$tmpdir"
  staging="$(find_staging_dir "$tmpdir")"
  [[ -x "${staging}/install-chartdldr-macos.sh" ]] || chmod +x "${staging}/install-chartdldr-macos.sh"

  fake_app="${tmpdir}/OpenCPN.app"
  mkdir -p "${fake_app}/Contents/PlugIns" \
           "${fake_app}/Contents/SharedSupport/plugins/chartdldr_pi" \
           "${fake_app}/Contents/MacOS"
  printf 'stub\n' > "${fake_app}/Contents/PlugIns/libchartdldr_pi.dylib"

  (cd "$staging" && ./install-chartdldr-macos.sh "$fake_app")

  local lib_dst data_dst
  lib_dst="${fake_app}/Contents/PlugIns/libchartdldr_pi.dylib"
  data_dst="${fake_app}/Contents/SharedSupport/plugins/chartdldr_pi/chart_sources.xml"

  assert_same_file "${staging}/PlugIns/libchartdldr_pi.dylib" "$lib_dst"
  [[ -f "$data_dst" ]] || fail "missing installed ${data_dst}"

  local backup
  backup="$(find "${fake_app}/Contents/PlugIns" -maxdepth 1 -name 'libchartdldr_pi.dylib.bak.*' | head -1)"
  [[ -n "$backup" ]] || fail "expected backup of pre-existing plugin on macOS"

    echo "macOS install script OK ($(basename "$zip"))"
  )
}

verify_windows() {
  (
    set -euo pipefail
    local zip staging work_root tmpdir fake_ocpn staging_win fake_win
    zip="$(to_slash "$(find_platform_zip 'chartdldr_pi-*-windows.zip')")"

    # MSYS /tmp and cmd.exe paths diverge on Git Bash; use the workspace tree instead.
    work_root="$(to_slash "${GITHUB_WORKSPACE:-$PWD}")/.ci-chartdldr-verify-$$"
    tmpdir="${work_root}/work"
    fake_ocpn="${work_root}/fake-opencpn"
    rm -rf "$work_root"
    mkdir -p "$tmpdir" "${fake_ocpn}/plugins/chartdldr_pi"
    trap 'rm -rf "$work_root"' EXIT

    extract_artifact "$zip" "$tmpdir"
    staging="$(to_slash "$(find_staging_dir "$tmpdir")")"

    printf 'old\n' > "${fake_ocpn}/plugins/chartdldr_pi.dll"
    printf 'stub\n' > "${fake_ocpn}/opencpn.exe"

    fake_win="$(win_path "$fake_ocpn")"

    # Run .bat from bash cwd; avoid cmd "cd /d path\" broken by trailing backslashes.
    MSYS2_ARG_CONV_EXCL='*'
    export MSYS2_ARG_CONV_EXCL
    (
      cd "$staging" || fail "cannot cd to staging: ${staging}"
      cmd.exe /C "install-chartdldr-windows.bat \"${fake_win}\""
    ) || fail "install-chartdldr-windows.bat failed"

    local lib_dst data_dst
    lib_dst="${fake_ocpn}/plugins/chartdldr_pi.dll"
    data_dst="${fake_ocpn}/plugins/chartdldr_pi/chart_sources.xml"

    assert_same_file "${staging}/plugins/chartdldr_pi.dll" "$lib_dst"
    [[ -f "$data_dst" ]] || fail "missing installed ${data_dst}"

    local backup
    backup="$(find "${fake_ocpn}/plugins" -maxdepth 1 -name 'chartdldr_pi.dll.bak.*' | head -1)"
    [[ -n "$backup" ]] || fail "expected backup of pre-existing plugin on Windows"

    echo "Windows install script OK ($(basename "$zip"))"
  )
}

verify_linux() {
  (
    set -euo pipefail
    local zip staging tmpdir home lib_dst data_dst backup
    zip="$(find_platform_zip 'chartdldr_pi-*-linux-arm64.zip')"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    extract_artifact "$zip" "$tmpdir"
  staging="$(find_staging_dir "$tmpdir")"
  [[ -x "${staging}/install-chartdldr-linux.sh" ]] || chmod +x "${staging}/install-chartdldr-linux.sh"

  # Isolated HOME (no Flatpak paths; install script uses ~/.local/...).
  home="${tmpdir}/home"
  mkdir -p "${home}/.local/lib/opencpn/plugins" \
           "${home}/.local/share/opencpn/plugins/chartdldr_pi"
  printf 'old\n' > "${home}/.local/lib/opencpn/plugins/libchartdldr_pi.so"

  (cd "$staging" && HOME="$home" ./install-chartdldr-linux.sh)

  lib_dst="${home}/.local/lib/opencpn/plugins/libchartdldr_pi.so"
  data_dst="${home}/.local/share/opencpn/plugins/chartdldr_pi/chart_sources.xml"

  assert_same_file "${staging}/lib/libchartdldr_pi.so" "$lib_dst"
  [[ -f "$data_dst" ]] || fail "missing installed ${data_dst}"

  backup="$(find "${home}/.local/lib/opencpn/plugins" -maxdepth 1 -name 'libchartdldr_pi.so.bak.*' | head -1)"
  [[ -n "$backup" ]] || fail "expected backup of pre-existing plugin on Linux"

    echo "Linux install script OK ($(basename "$zip"))"
  )
}

case "$PLATFORM" in
  linux) verify_linux ;;
  macos) verify_macos ;;
  windows) verify_windows ;;
  *) usage ;;
esac
