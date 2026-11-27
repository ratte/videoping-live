# -*- mode: ruby -*-
# Build and test VM for the videoping live image (Debian 13 + live-build), see README.md.
#
# `vagrant up` installs the build tools, builds the videoping .deb (debs/), the live ISO (out/)
# and boots the ISO headless in QEMU as a smoke test.
#
# Tunables (environment variables on the host):
#   VP_BOX          vagrant box for the build VM           (default bento/debian-13)
#   VP_CPUS         cpus of the build VM                   (default 4)
#   VP_MEMORY       RAM of the build VM in MB              (default 8192)
#   VP_SRC          videoping source folder on the host    (default ../videoping if it exists,
#                                                           else a clone of VP_REPO)
#   VP_REPO         videoping git repository               (default https://github.com/toastbrotch/videoping.git)
#   VP_REF          branch or tag of VP_REPO               (default main)
#   VP_REBUILD_DEB  1: build a new videoping .deb even if debs/ has one
#   VP_KERNEL       amd64 (default) or rt-amd64 (PREEMPT_RT kernel)

BOX    = ENV.fetch("VP_BOX", "bento/debian-13")
CPUS   = ENV.fetch("VP_CPUS", "4").to_i
MEMORY = ENV.fetch("VP_MEMORY", "8192").to_i
VP_SRC = ENV.fetch("VP_SRC") { File.exist?(File.join(__dir__, "../videoping/Cargo.toml")) ? "../videoping" : "" }

PASS_ENV = %w[VP_REPO VP_REF VP_REBUILD_DEB VP_KERNEL VP_BOOTAPPEND_EXTRA VP_SMOKE_TIMEOUT VP_SMOKE_ACCEL]
  .each_with_object({}) { |k, h| h[k] = ENV[k] if ENV[k] }

Vagrant.configure("2") do |config|
  config.vm.box = BOX
  config.vm.hostname = "videoping-live-builder"
  config.vm.boot_timeout = 600

  # this repository; debs/ and out/ are written from inside the VM
  config.vm.synced_folder ".", "/vagrant"
  config.vm.synced_folder VP_SRC, "/videoping-src", mount_options: ["ro"] unless VP_SRC.empty?

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "videoping-live-builder"
    vb.gui    = false
    vb.cpus   = CPUS
    vb.memory = MEMORY
    # No nested virtualization: with VirtualBox 7.2 it corrupted guest memory and crashed the VM
    # (PGMAllPool assertion). The smoke test's QEMU uses software emulation instead.
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "off"]
    vb.customize ["modifyvm", :id, "--audio-enabled", "off"]
  end

  config.vm.provision "packages", type: "shell", path: "provision/10-packages.sh"
  config.vm.provision "rust",     type: "shell", path: "provision/20-rust.sh", privileged: false
  config.vm.provision "deb",      type: "shell", privileged: false, env: PASS_ENV,
    inline: "/vagrant/scripts/build-videoping-deb.sh"
  config.vm.provision "iso",      type: "shell", env: PASS_ENV,
    inline: "/vagrant/scripts/build-iso.sh"
  config.vm.provision "smoke",    type: "shell", env: PASS_ENV,
    inline: "/vagrant/scripts/smoke-test.sh"
end
