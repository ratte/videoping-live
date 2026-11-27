#!/bin/bash
# Smoke test: boot the ISO headless in QEMU (KVM if available, else software emulation) and check
# on the serial console that the live system comes up, starts the X session and keeps videoping
# running. Takes a screenshot (out/smoke-test/screen.png).
#
#   scripts/smoke-test.sh [iso]     (default: out/videoping-live-latest.iso)
#
# The kernel and initrd are taken from the ISO so the serial console can be added to the kernel
# command line; everything else is the same as booting from the ISO's menu.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="$(readlink -f "${1:-$ROOT/out/videoping-live-latest.iso}")"
WORK="$ROOT/out/smoke-test"
TMP="$(mktemp -d)"
trap 'kill "$QPID" 2>/dev/null; rm -rf "$TMP"' EXIT
rm -rf "$WORK"; mkdir -p "$WORK"

[ -f "$ISO" ] || { echo "smoke-test: no ISO at $ISO"; exit 1; }
xorriso -osirrox on -indev "$ISO" -extract /live/vmlinuz "$TMP/vmlinuz" -extract /live/initrd.img "$TMP/initrd.img" >/dev/null 2>&1 \
  || { echo "smoke-test: could not extract /live/vmlinuz and /live/initrd.img from the ISO"; exit 1; }

# VP_SMOKE_ACCEL: auto (KVM if /dev/kvm is usable), kvm, or tcg (software emulation). Nested KVM
# inside a VirtualBox 7.2 VM corrupted the guest's memory ("BUG: Bad page state"), so the
# Vagrant VM has nested virtualization off and this falls back to tcg.
case "${VP_SMOKE_ACCEL:-auto}" in
  kvm) USE_KVM=1 ;; tcg) USE_KVM=0 ;; *) [ -w /dev/kvm ] && USE_KVM=1 || USE_KVM=0 ;;
esac
if [ "$USE_KVM" = 1 ]; then ACCEL="-enable-kvm -cpu host"; TIMEOUT=${VP_SMOKE_TIMEOUT:-300}; echo "smoke-test: KVM"
else ACCEL="-cpu max"; TIMEOUT=${VP_SMOKE_TIMEOUT:-1500}; echo "smoke-test: no KVM, software emulation (slow)"; fi

APPEND="$(cat "$ROOT/live/bootappend") console=ttyS0,115200 systemd.journald.forward_to_console=1 systemd.journald.max_level_console=info"
# shellcheck disable=SC2086
qemu-system-x86_64 $ACCEL -m 4096 -smp 2 \
  -cdrom "$ISO" -kernel "$TMP/vmlinuz" -initrd "$TMP/initrd.img" -append "$APPEND" \
  -device virtio-vga -display none \
  -audiodev none,id=snd0 -device intel-hda -device hda-duplex,audiodev=snd0 \
  -device qemu-xhci -device usb-tablet \
  -nic user,model=virtio-net-pci \
  -serial "file:$WORK/serial.log" -monitor "unix:$TMP/monitor.sock,server,nowait" &
QPID=$!

ok=0
for ((t = 0; t < TIMEOUT; t += 5)); do
  sleep 5
  kill -0 "$QPID" 2>/dev/null || { echo "smoke-test: QEMU stopped"; break; }
  if grep -q "videoping running" "$WORK/serial.log"; then ok=1; break; fi
done
# give videoping-live-info time to log and videoping time to draw (slow without KVM), then
# take a screenshot
[ $ok = 1 ] && { [ "$USE_KVM" = 1 ] && sleep 20 || sleep 120; }
echo "screendump $TMP/screen.ppm" | socat - "UNIX-CONNECT:$TMP/monitor.sock" >/dev/null 2>&1
sleep 2
[ -f "$TMP/screen.ppm" ] && pnmtopng "$TMP/screen.ppm" > "$WORK/screen.png" 2>/dev/null

echo "--- from the serial console:"
grep -a -E "videoping(-live)?\[[0-9]+\]:" "$WORK/serial.log" | sed 's/\x1b\[[0-9;]*m//g; s/^.*\]: //' | grep -v '^$' | head -40
if [ $ok = 1 ]; then
  echo "smoke-test: OK (videoping is running; log: $WORK/serial.log, screenshot: $WORK/screen.png)"
else
  echo "smoke-test: FAILED (no 'videoping running' within ${TIMEOUT}s; log: $WORK/serial.log)"
  tail -n 30 "$WORK/serial.log"
  exit 1
fi
