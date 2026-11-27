videoping live
==============

A bootable live Linux image (USB stick or DVD) that starts
[videoping](https://github.com/toastbrotch/videoping) automatically: plug in the stick,
boot, play. Nothing is installed on the machine's disk.

- **Debian 13 "trixie"**, built with Debian's official [live-build](https://live-team.pages.debian.net/live-manual/)
- boots on BIOS and UEFI machines (hybrid ISO, can be written to a USB stick as it is). The
  boot menu starts the live system after 3 seconds, so no keyboard is needed
- logs in automatically and starts **videoping full screen**. If videoping quits or crashes,
  it starts again within a few seconds
- **audio for VJing**: PipeWire with PulseAudio, ALSA and **JACK** clients, realtime
  scheduling (rtkit plus limits for the `audio` group), and the kernel booted with
  `threadirqs preempt=full`. USB autosuspend is off, so audio interfaces and MIDI controllers
  don't drop out. Optional PREEMPT_RT kernel
- **USB audio interfaces**: every class-compliant interface works through the kernel's
  `snd-usb-audio` driver. The image also has the firmware loaders for older devices that need
  them, the ALSA UCM profiles, `alsa-scarlett-gui` for Focusrite Scarlett / Clarett mixers,
  `pavucontrol` (mixer) and `qpwgraph` (audio and MIDI patchbay). PipeWire follows the sample
  rate of the device (44.1, 48, 88.2 or 96 kHz)
- **video**: Mesa OpenGL for Intel, AMD and NVIDIA (nouveau), VA-API hardware decoding,
  the full GStreamer plugin set, and the GPU firmware
- **MIDI**: ALSA, class-compliant USB MIDI controllers need no driver
- **network**: NetworkManager (internet for videopong.net and the AI tab), Avahi / mDNS for NDI
  discovery
- **clips on a USB stick**: sticks and disks are mounted automatically under `/media/vj/<label>`.
  exFAT, FAT, NTFS and ext4 all work
- screens: every connected screen is switched on, side by side from left to right. The first
  one shows the videoping ui, and the output goes to whichever screen you choose in videoping

Not included: the NDI runtime (`libndi.so.6`, proprietary license) and the proprietary NVIDIA
driver. The NDI runtime can be installed on the running live system, see below.

## using the live system

Write the ISO to a USB stick, for example `sudo dd if=videoping-live-….iso of=/dev/sdX bs=4M
conv=fsync status=progress` (all data on the stick is lost) or with any USB image writer.
Then boot from the stick.

| keys | |
|---|---|
| right click on the desktop, or **Ctrl+Alt+M** | menu: restart videoping, screens, audio, network, terminal, log, reboot, power off |
| **Ctrl+Alt+R** | restart videoping |
| **Ctrl+Alt+S** | arrange the screens again (after plugging in a projector) |
| **Ctrl+Alt+A** | audio mixer (pavucontrol) |
| **Ctrl+Alt+P** | audio / MIDI patchbay (qpwgraph) |
| **Ctrl+Alt+T** | terminal |
| **Ctrl+Alt+F2** … **F6** | text consoles; **Ctrl+Alt+F1** goes back |

- **NDI**: menu → *Install NDI runtime* (or `videoping-install-ndi` in a terminal). It takes
  `Install_NDI_SDK_v6_Linux.tar.gz` from a USB stick if one has it (works offline), otherwise
  downloads it from ndi.tv, runs Vizrt's installer (read and accept the NDI license with `y`)
  and copies `libndi.so*` to `~/.local/lib`, following videoping's `install.md`. Like everything
  else it is gone after a reboot, unless you use persistence
- user `vj`, password `live`, `sudo` without a password
- logs: `journalctl -b -t videoping-live -t videoping`. `videoping-live` lists the GPU, audio
  cards, audio inputs and outputs and the MIDI devices found at startup
- debugging: add `videoping.noautostart` to the kernel command line (press `e` / `Tab` in the
  boot menu) to get a plain console on tty1 instead of the session
- keyboard layout `ch`, time zone `Europe/Zurich`, English ui. Change them in `live/bootappend`
  (`keyboard-layouts=de`, `us`, … / `timezone=…`) or at boot in the boot menu

**Nothing is saved**: the live system starts fresh on every boot (videoping settings, MIDI
mappings, the AI key). Keep clips and sessions on a USB stick, or set up live-boot
[persistence](https://live-team.pages.debian.net/live-manual/html/live-manual/customizing-run-time-behaviours.en.html#persistence)
(a partition labelled `persistence` with a `persistence.conf` containing `/home union`, and
`persistence` added to the kernel command line).

## build and test with Vagrant

Requirements on the host: VirtualBox 7 and Vagrant 2.4 (tested: VirtualBox 7.2.22,
Vagrant 2.4.9), about 30 GB free disk. Building takes 30 to 60 minutes the first time.

```sh
vagrant up
```

This starts a Debian 13 build VM (`bento/debian-13`) and runs, as Vagrant provisioners:

| step | | result |
|---|---|---|
| `packages` | live-build, QEMU, videoping build dependencies | |
| `rust` | Rust via rustup | |
| `deb` | builds the videoping `.deb` on Debian 13 (`scripts/build-videoping-deb.sh`) | `debs/videoping_*.deb` |
| `iso` | builds the live ISO (`scripts/build-iso.sh`) | `out/videoping-live-<date>-amd64.iso` |
| `smoke` | boots the ISO headless in QEMU, checks on the serial console that videoping runs and that the screen is not one flat colour (`scripts/smoke-test.sh`) | `out/smoke-test/serial.log`, `screen.png` |

The build VM has nested virtualization turned off: with VirtualBox 7.2, KVM inside the VM
corrupted the test system's memory and then crashed the build VM. The smoke test therefore uses
QEMU's software emulation. That is slow (about 5 minutes) but reliable.

Rebuild after a change:

```sh
vagrant provision --provision-with iso,smoke            # image only
VP_REBUILD_DEB=1 vagrant provision --provision-with deb,iso,smoke   # new videoping too
```

Test it by hand in a VirtualBox window, on the host (two screens, sound, USB pass-through):

```sh
scripts/run-virtualbox.sh               # boots out/videoping-live-latest.iso
VP_FIRMWARE=efi scripts/run-virtualbox.sh   # the same, UEFI boot
scripts/run-virtualbox.sh --delete      # remove the test VM
```

`VP_VBOX_UI=headless` starts it without a window (take screenshots with
`VBoxManage controlvm videoping-live-test screenshotpng shot.png`). Other settings: `VP_MONITORS`
(default 2), `VP_3D`, `VP_MEMORY`.

To test a USB audio interface or MIDI controller in the test VM, select it in the VM window
under *Devices → USB* (VirtualBox needs the Extension Pack for USB 3, and your host user in the
`vboxusers` group).

VirtualBox and QEMU only emulate the GPU (no hardware video decoding, slow 3D), so check
performance on real hardware.

### settings

Environment variables for `vagrant up` / `vagrant provision`:

| variable | default | |
|---|---|---|
| `VP_SRC` | `../videoping` if it exists | videoping source folder on the host (the working tree as it is, uncommitted changes included). Without it: a git clone of `VP_REPO`. Changing it needs `vagrant reload` |
| `VP_REPO` | `https://github.com/toastbrotch/videoping.git` | videoping repository |
| `VP_REF` | `main` | branch or tag |
| `VP_REBUILD_DEB` | unset | `1`: build a new `.deb` even if `debs/` has one |
| `VP_KERNEL` | `amd64` | `rt-amd64`: Debian's PREEMPT_RT kernel |
| `VP_BOOTAPPEND_EXTRA` | unset | extra kernel parameters |
| `VP_SMOKE_ACCEL` | `auto` | smoke test: `kvm` or `tcg` (software emulation) |
| `VP_SMOKE_TIMEOUT` | 300 s (KVM), 1500 s (tcg) | smoke test: how long to wait for videoping |
| `VP_BOX`, `VP_CPUS`, `VP_MEMORY` | `bento/debian-13`, `4`, `8192` | build VM |

A ready-made videoping `.deb` can also be put into `debs/`. Every `.deb` there goes into the
image. It must work on Debian 13 (packages built on Ubuntu 24.04 usually do).

### without Vagrant

On a Debian 13 machine, as root:

```sh
apt install live-build
scripts/build-videoping-deb.sh   # as a normal user with Rust; or put a .deb into debs/
sudo scripts/build-iso.sh
scripts/smoke-test.sh            # needs qemu-system-x86, xorriso, socat, netpbm
```

## tested

On 2026-11-27, on a Linux host with VirtualBox 7.2.22, Vagrant 2.4.9, box `bento/debian-13`
v202510.26.0, videoping 0.1.0 (723b0d9 plus local changes):

- the first `vagrant up` took about 50 minutes: build tools 5 min, videoping `.deb` 10 min,
  ISO 20 min (1.4 GB), smoke test 5 min. A rebuild of the ISO alone takes about 10 minutes
- smoke test (QEMU, software emulation): `smoke-test: OK`. The log shows kernel 6.12 with
  `preempt=full`, Mesa 25.0 llvmpipe with OpenGL 4.5, `PulseAudio (on PipeWire 1.4.2)` with
  the emulated Intel HDA card as sink and source, and videoping running
- VirtualBox, BIOS and UEFI: the boot menu times out after 3 s, and videoping comes up full
  screen without a window frame (60 fps in the BIOS VM)
- not tested yet: real hardware, USB audio interfaces, MIDI controllers, two screens

## how it works

| file | |
|---|---|
| `live/auto/config` | live-build options (Debian 13, amd64, non-free firmware, hybrid ISO) |
| `live/bootappend` | kernel command line: live user, locale, keyboard, low-latency options |
| `live/config/bootloaders/` | boot menu timeout (3 s) for BIOS (isolinux) and UEFI (GRUB) |
| `live/config/package-lists/videoping-live.list.chroot` | the packages in the image |
| `live/config/hooks/live/0100-videoping-live.hook.chroot` | services, run inside the image during the build |
| `live/config/includes.chroot/` | files copied into the image |
| `…/etc/systemd/system/getty@tty1.service.d/` | autologin of user `vj` on tty1 |
| `…/etc/profile.d/videoping-live.sh` | the login on tty1 runs `startx videoping-session` |
| `…/usr/local/bin/videoping-session` | the X session: Openbox, screens, USB automount, videoping in a restart loop |
| `…/usr/local/bin/videoping-screens` | turns on and arranges all connected screens |
| `…/usr/local/bin/videoping-live-info` | logs GPU, audio and MIDI devices to the journal |
| `…/etc/videoping-live/openbox*.xml` | window manager keys, menu, videoping window without a frame |
| `…/etc/security/limits.d/`, `…/etc/pipewire/pipewire.conf.d/` | realtime audio limits, PipeWire sample rates |

Why X11 and not Wayland: X11 with a small window manager behaves the same on every GPU and in
VMs, and it makes placing the output window on a second screen or projector simple.

Why Debian and not Ubuntu Studio: Ubuntu Studio is a full desktop with many audio and media
programs. Here a small system that boots straight into videoping is what's needed. Debian's
live-build makes it reproducible from a few text files, and Debian 13 has a current audio
stack (PipeWire 1.4, kernel 6.12) and the non-free firmware in the official archive.

## license

[GPL 3.0 or later](LICENSE), like videoping. The image contains Debian packages under their
own licenses, including non-free firmware.
