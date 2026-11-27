#!/bin/bash
# Build the live ISO with live-build (needs root and a Debian 13 host, e.g. the Vagrant VM).
# The build runs on the local disk (VP_BUILD_DIR, default /var/lib/videoping-live/build; the
# download cache stays there between builds); the ISO lands in out/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${VP_BUILD_DIR:-/var/lib/videoping-live/build}"
OUT="$ROOT/out"

[ "$(id -u)" = 0 ] || { echo "build-iso: run as root"; exit 1; }
ls "$ROOT"/debs/videoping_*.deb >/dev/null 2>&1 \
  || { echo "build-iso: no videoping_*.deb in debs/ (run scripts/build-videoping-deb.sh)"; exit 1; }

mkdir -p "$BUILD" "$OUT"
cd "$BUILD"
[ -d config ] && lb clean
rm -rf auto config bootappend
cp -a "$ROOT/live/auto" "$ROOT/live/config" "$ROOT/live/bootappend" .
mkdir -p config/packages.chroot
cp "$ROOT"/debs/*.deb config/packages.chroot/
# the copy comes from a shared folder: files in the image belong to root, with sane modes
chown -R root:root auto config bootappend
find config/includes.chroot -type d -exec chmod 755 {} +
find config/includes.chroot -type f -exec chmod 644 {} +
chmod 755 auto/* config/hooks/live/* config/includes.chroot/usr/local/bin/*

lb config
lb build

ISO="$BUILD/live-image-amd64.hybrid.iso"
[ -f "$ISO" ] || { echo "build-iso: no ISO, see $BUILD/build.log"; exit 1; }
NAME="videoping-live-$(date +%Y%m%d)-amd64"
cp "$ISO" "$OUT/$NAME.iso"
cp "$BUILD/live-image-amd64.packages" "$OUT/$NAME.packages" 2>/dev/null || true
(cd "$OUT" && sha256sum "$NAME.iso" > "$NAME.iso.sha256")
ln -sfn "$NAME.iso" "$OUT/videoping-live-latest.iso"
echo "build-iso: $OUT/$NAME.iso ($(du -h "$OUT/$NAME.iso" | cut -f1))"
