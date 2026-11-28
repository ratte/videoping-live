#!/bin/bash
# Build the videoping .deb and the live ISO and run the smoke test, in one go, as root on a
# Debian 13 system: the CI build (.github/workflows/build-iso.yml runs it in a privileged
# debian:trixie container). The same steps as the Vagrant provisioners.
#
#   scripts/ci-build.sh
#
# Environment: VP_REPO, VP_REF (videoping source, default main), VP_KERNEL, VP_BOOTAPPEND_EXTRA,
# VP_SMOKE_ACCEL, VP_SMOKE_TIMEOUT, VP_SKIP_SMOKE=1 (no smoke test), VP_ISO_NAME (file name of the
# ISO in out/ without .iso, default videoping-live-<date>-amd64).
# Writes out/<name>.iso, .iso.sha256, .packages and out/build-info.txt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" = 0 ] || { echo "ci-build: run as root"; exit 1; }
step() { echo; echo "::group::$*" 2>/dev/null; echo "== ci-build: $*"; }
endstep() { echo "::endgroup::"; }

step "packages"
"$ROOT/provision/10-packages.sh"
# the checkout belongs to another user than root in the container
git config --global --add safe.directory '*'
endstep

step "rust"
"$ROOT/provision/20-rust.sh"
endstep

step "videoping .deb (${VP_REPO:-toastbrotch/videoping} ${VP_REF:-main})"
rm -f "$ROOT"/debs/videoping_*.deb
VP_REBUILD_DEB=1 "$ROOT/scripts/build-videoping-deb.sh"
endstep

step "ISO"
"$ROOT/scripts/build-iso.sh"
built="$(readlink -f "$ROOT/out/videoping-live-latest.iso")"
name="${VP_ISO_NAME:-$(basename "$built" .iso)}"
if [ "$built" != "$ROOT/out/$name.iso" ]; then
  mv "$built" "$ROOT/out/$name.iso"
  mv "${built%.iso}.packages" "$ROOT/out/$name.packages" 2>/dev/null || true
  rm -f "$built.sha256"
  ln -sfn "$name.iso" "$ROOT/out/videoping-live-latest.iso"
fi
(cd "$ROOT/out" && sha256sum "$name.iso" > "$name.iso.sha256")
endstep

{
  echo "iso: $name.iso ($(du -h "$ROOT/out/$name.iso" | cut -f1))"
  echo "sha256: $(cut -d' ' -f1 "$ROOT/out/$name.iso.sha256")"
  echo "videoping: $(basename "$ROOT"/debs/videoping_*.deb) from ${VP_REPO:-https://github.com/toastbrotch/videoping.git} ${VP_REF:-main} ($(git -C "$HOME/videoping" rev-parse --short HEAD 2>/dev/null || echo '?'))"
  echo "kernel: $(sed -n 's/^linux-image-\([^ \t]*\).*/\1/p' "$ROOT/out/$name.packages" 2>/dev/null | head -n 1)"
  echo "videoping-live: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
} > "$ROOT/out/build-info.txt"
cat "$ROOT/out/build-info.txt"

if [ "${VP_SKIP_SMOKE:-0}" != 1 ]; then
  step "smoke test"
  "$ROOT/scripts/smoke-test.sh" "$ROOT/out/$name.iso"
  endstep
fi
