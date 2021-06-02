#!/bin/bash
# vim:noexpandtab

set -eu -o pipefail
set -x

CONF_DIR="$(realpath $(dirname "${BASH_SOURCE[0]}")/..)"
source $CONF_DIR/conf

mkkvm() {
	local kvmimage=${VM_IMAGES[$1]}
	local kvmdir=${VM_DIRS[$1]}

	if [ -f "$kvmimage" ]; then
		set +x
		echo "file $kvmimage already exists. Bailing out"
		exit 1
	fi

	sudo modprobe nbd
	mkdir -p $kvmdir
    #sudo qemu-img create -f qcow2 -b $(basename $KUBEADMIMG) $kvmimage
	cp $KUBEADMIMG $kvmimage
	sudo qemu-nbd -d $NBDDEV
	sudo qemu-nbd -c $NBDDEV $kvmimage
	sudo mount $NBDDEV $kvmdir
}

cleanup() {
	local kvmdir=${VM_DIRS[$1]}
	sync
	sudo umount $kvmdir
	sudo qemu-nbd -d $NBDDEV
}

xconfig() {
	local xname=${VM_NAMES[$1]}
	local kvmdir=${VM_DIRS[$1]}
	sudo sh -c "echo $xname > $kvmdir/etc/hostname"
}

main() {
	mkkvm $1
	xconfig $1
	cleanup $1
}


main $1
