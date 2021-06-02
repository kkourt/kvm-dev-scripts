#!/bin/bash
# vim:noexpandtab

set -eu -o pipefail
set -x

CONF_DIR="$(realpath $(dirname "${BASH_SOURCE[0]}")/..)"
source $CONF_DIR/conf

kvm() {
	local image=${VM_IMAGES[$1]}
	local netdev_mac=${VM_NICS_MACS[$1]}
	local netdev="e1000"
	#local netdev="virtio-net"

	declare -a qemu_opts=("-enable-kvm" "-m" "2G" "-smp" "2")
	qemu_opts+=("-kernel" "$KERNEL_SOURCE/arch/x86/boot/bzImage")
	qemu_opts+=("-append" "root=/dev/vda rw console=hvc0")
	qemu_opts+=("-drive" "file=$image,media=disk,if=virtio")
	qemu_opts+=("-chardev" "stdio,id=stdio,mux=on,signal=off")
	qemu_opts+=("-device" "virtio-serial-pci")
	qemu_opts+=("-device" "virtconsole,chardev=stdio")
	qemu_opts+=("-mon" "chardev=stdio")
	qemu_opts+=("-display" "none")
	qemu_opts+=("-netdev" "bridge,br=${BRIDGE_IFACE},id=n0" "-device" "$netdev,netdev=n0,mac=$netdev_mac")
	##qemu_opts+=("-net user,hostfwd=tcp:127.0.0.1:5001-:22")
	qemu_opts+=("-fsdev" "local,id=fs1,path=/home,security_model=none")
	qemu_opts+=("-device" "virtio-9p-pci,fsdev=fs1,mount_tag=home")
	qemu_opts+=("-fsdev" "local,id=fs2,path=$CONF_DIR/modules/lib/modules,security_model=none")
	qemu_opts+=("-device" "virtio-9p-pci,fsdev=fs2,mount_tag=modules")

	sudo qemu-system-x86_64 "${qemu_opts[@]}"
}

kvm $1
