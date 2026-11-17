#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build a private Popsicle overlay from the matching OS4.0.6.0.XPBCNXM ROM.
Usage: extract-overlay.sh --system DIR --vendor DIR --odm DIR --modem DIR --out DIR
EOF
}
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
system_root= vendor_root= odm_root= modem_root= out=
while (($#)); do
  case "$1" in
    --system|--vendor|--odm|--modem|--out)
      (($# >= 2)) || die "missing value for $1"
      case "$1" in
        --system) system_root=$2;; --vendor) vendor_root=$2;;
        --odm) odm_root=$2;; --modem) modem_root=$2;; --out) out=$2;;
      esac
      shift 2;;
    -h|--help) usage; exit 0;;
    *) usage >&2; die "unknown argument: $1";;
  esac
done
for pair in "system:$system_root" "vendor:$vendor_root" "odm:$odm_root" "modem:$modem_root"; do
  [[ -d "${pair#*:}" ]] || die "--${pair%%:*} must name an extracted ROM directory"
done
[[ -n "$out" && ! -e "$out" ]] || die '--out must name a new directory'
mkdir -p "$out"
script_dir=$(cd "$(dirname "$0")" && pwd)
copy_file() {
  local source=$1 destination=$2 mode=${3:-0644}
  [[ -f "$source" ]] || die "required ROM file is missing: $source"
  mkdir -p "$(dirname "$destination")"
  install -m "$mode" "$source" "$destination"
}
copy_first() {
  local destination=$1 source
  shift
  for source in "$@"; do
    if [[ -f "$source" ]]; then copy_file "$source" "$out/$destination"; return; fi
  done
  die "required file is missing: $destination"
}
copy_file "$script_dir/secure-element-ta-setup.sh" "$out/system/bin/secure-element-ta-setup.sh" 0755
for uuid in 05B04A44-BF30-42DF-9E2F-B366B980ED19 32552B22-89FE-42B4-8A45-A0C4E2DB0326 FD719D50-FFFB-11EB-9A03-0242AC130003; do
  for suffix in b00 b01 b02 b03 b04 b05 b06 b07 b08 mdt; do
    name="$uuid.$suffix"
    mapfile -d '' matches < <(find "$modem_root" -type f -name "$name" -print0)
    ((${#matches[@]} == 1)) || die "expected exactly one $name under modem"
    copy_file "${matches[0]}" "$out/system/bin/twrp_secure_element_ta/$name"
  done
done
for name in cs40l26.wmfw cs40l26.bin cs40l26-calib.wmfw cs40l26-calib.bin cs40l26-a2h.bin cs40l26-a2h1.bin cs40l26-dbc.bin cs40l26-dvl.bin cs40l26-lf0t.bin cs40l26-svc.bin; do
  copy_first "lib/firmware/$name" "$odm_root/firmware/$name" "$odm_root/firmware/image/$name" "$odm_root/etc/firmware/$name" "$vendor_root/firmware/$name" "$vendor_root/firmware/image/$name" "$vendor_root/etc/firmware/$name"
done
# Weaver must resolve these through recovery's default linker namespace,
# including when a privileged executable does not use LD_LIBRARY_PATH.
copy_first system/lib64/libvndksupport.so "$system_root/lib64/libvndksupport.so"
copy_first system/lib64/libdl_android.so "$system_root/lib64/bootstrap/libdl_android.so" "$system_root/lib64/libdl_android.so"
{
  printf 'device=popsicle\nrom=OS4.0.6.0.XPBCNXM\n'
  printf 'system=%s\nvendor=%s\nodm=%s\nmodem=%s\n' "$system_root" "$vendor_root" "$odm_root" "$modem_root"
  find "$out" -type f -exec sha256sum {} \; | sort
} > "$out/LOCAL-SOURCES.txt"
printf 'Created private Popsicle overlay: %s\n' "$out"
