#!/bin/bash
# Build VM packages: live-build, QEMU for the smoke test, and the videoping build dependencies
# (see dev.md of videoping).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# The GRUB packages (for the ISO's boot menu) pull in grub-pc. Its setup must not touch the
# VM's own boot loader, so it is told there is no disk to install to.
echo "grub-pc grub-pc/install_devices multiselect" | debconf-set-selections
echo "grub-pc grub-pc/install_devices_empty boolean true" | debconf-set-selections
dpkg --configure -a

apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools dosfstools \
  syslinux syslinux-common isolinux \
  qemu-system-x86 qemu-utils ovmf socat netpbm \
  build-essential pkg-config curl ca-certificates git rsync dpkg-dev binutils \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libasound2-dev
