# Xiaomi 17 Pro Max (`popsicle`)

This configuration targets `OS4.0.6.0.XPBCNXM` and the CS40L26 firmware
`42.0.26`. It ports the Popsicle hardware support from upstream PR #42 onto
main's 0.3.1 service discovery and built-in Rust OMAPI implementation. It does
not install a second OMAPI service or replace main's KeyMint discovery.

The earlier PR build was checked on the target phone. A newly built main-based
image must still be checked on the phone before calling it device-validated.

## Private ROM overlay

Use files from the exact ROM installed on the phone. The overlay contains
CS40L26 firmware, secure-element trusted applications, and the two system
libraries needed by Weaver in recovery. These proprietary files stay local;
do not commit the overlay, its archive, or `LOCAL-SOURCES.txt`.

On Linux or WSL:

```sh
bash tools/popsicle/extract-overlay.sh \
  --system /path/to/extracted/system \
  --vendor /path/to/extracted/vendor \
  --odm /path/to/extracted/odm \
  --modem /path/to/extracted/modem \
  --out /path/to/private/popsicle-overlay
```

The extracted roots retain their partition layout: for example,
`system/lib64/libvndksupport.so`, `odm/firmware/cs40l26.wmfw`, and the TA
segments below the modem root. Build the overlay on a Linux filesystem so
executable permissions are retained.

## Build the image

Build main's tools with Rust 1.100.0, cargo-ndk 4.1.2 and Android NDK r29.
The stock Recovery SHA-256 must be
`cfd845ae5b18812757ba83170d0dce690bb998d1310e7bc0b186e362be7ad9e5`.

```sh
cargo ndk -t arm64-v8a --platform 30 build --locked --release -p skyward
RUSTFLAGS='-C target-feature=+crt-static' cargo ndk -t arm64-v8a --platform 30 \
  build --locked --release -p skyward-system-init --target-dir target/system-init
cargo build --locked --release -p skyward-pack
target/release/skyward-pack recovery \
  --stock /path/to/OS4.0.6.0/recovery.img \
  --binary target/aarch64-linux-android/release/skyward \
  --system-init target/system-init/aarch64-linux-android/release/system-init \
  --config devices/popsicle.toml \
  --font resources/fonts/MiSansVF.ttf \
  --mono resources/fonts/KirkMono-Regular.ttf \
  --mono-license resources/fonts/KirkMono-OFL.txt \
  --overlay /path/to/private/popsicle-overlay \
  --out /path/to/skyward-main-popsicle.img
```

Without the matching private overlay, full haptics and hardware-backed data
decryption are not provided. Haptic initialization or playback failures disable
feedback and keep Recovery running. Do not use firmware from another ROM build.
