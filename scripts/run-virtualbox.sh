#!/bin/bash
# Boot the live ISO in a VirtualBox window on the host, for testing by hand: like a real
# machine with no disk, two screens, sound (in and out) and a USB 3 controller (pass through a
# USB audio interface or MIDI controller from the VM window's Devices → USB menu).
#
#   scripts/run-virtualbox.sh [iso]     (default: out/videoping-live-latest.iso)
#   scripts/run-virtualbox.sh --delete  (remove the test VM)
#
# Environment: VP_TEST_VM (VM name, default videoping-live-test), VP_FIRMWARE (bios | efi,
# default bios), VP_MONITORS (default 2), VP_3D (on | off, default on), VP_MEMORY (default 4096),
# VP_VBOX_UI (gui | headless, default gui).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VM="${VP_TEST_VM:-videoping-live-test}"

running() { VBoxManage list runningvms | grep -q "^\"$VM\" "; }
exists()  { VBoxManage showvminfo "$VM" >/dev/null 2>&1; }
stop()    { if running; then VBoxManage controlvm "$VM" poweroff; sleep 2; fi; }

if [ "${1:-}" = "--delete" ]; then
  exists || { echo "no VM $VM"; exit 0; }
  stop; VBoxManage unregistervm "$VM" --delete; echo "deleted $VM"; exit 0
fi

ISO="$(readlink -f "${1:-$ROOT/out/videoping-live-latest.iso}")"
[ -f "$ISO" ] || { echo "no ISO at $ISO (build it first: vagrant up)"; exit 1; }

if ! exists; then
  VBoxManage createvm --name "$VM" --ostype Debian_64 --register
  VBoxManage storagectl "$VM" --name SATA --add sata --portcount 1
fi
stop

VBoxManage modifyvm "$VM" \
  --memory "${VP_MEMORY:-4096}" --cpus 2 \
  --firmware "${VP_FIRMWARE:-bios}" \
  --graphicscontroller vmsvga --vram 128 --accelerate-3d "${VP_3D:-on}" \
  --monitor-count "${VP_MONITORS:-2}" \
  --audio-enabled on --audio-controller hda --audio-driver default --audio-in on --audio-out on \
  --usb-xhci on --mouse usbtablet \
  --nic1 nat \
  --boot1 dvd --boot2 none --boot3 none --boot4 none
VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --type dvddrive --medium "$ISO"
VBoxManage startvm "$VM" --type "${VP_VBOX_UI:-gui}"
echo "started $VM with $ISO"
