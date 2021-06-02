#!/bin/bash
# vim:noexpandtab

set -eu -o pipefail
set -x

CONF_DIR="$(realpath $(dirname "${BASH_SOURCE[0]}")/..)"
source $CONF_DIR/conf

function mkimage() {
	if [ -f "$ROOTIMG" ]; then
		set +x
		echo "file $ROOTIMG already exists. Bailing out"
		exit 1
	fi

	sudo modprobe nbd
	mkdir -p $ROOTDIR
	mkdir -p $(dirname $ROOTIMG)
	sudo qemu-img create -f qcow2 $ROOTIMG 8G
	sudo qemu-nbd -d $NBDDEV
	sudo qemu-nbd -c $NBDDEV $ROOTIMG
	sudo mkfs.ext4 $NBDDEV
	sudo mount $NBDDEV $ROOTDIR
	sudo debootstrap --include=$(IFS=, ; echo "${PACKAGES[*]}")  sid $ROOTDIR
}

function mntimage() {
	sudo modprobe nbd
	mkdir -p $ROOTDIR
	sudo qemu-nbd -d $NBDDEV
	sudo qemu-nbd -c $NBDDEV $ROOTIMG
	sudo mount $NBDDEV $ROOTDIR
}

function chrootconfig() {
	sudo chroot $ROOTDIR sh <<- ENDCHROOT
		apt-get update
		apt-get upgrade
		passwd -d root
		update-alternatives --set iptables /usr/sbin/iptables-legacy
	ENDCHROOT
}

function miscconfig() {

	cat <<- ENDSSHDCONFIG | sudo tee -a  $ROOTDIR/etc/ssh/sshd_config
	PermitRootLogin yes
	ENDSSHDCONFIG

	sudo mkdir $ROOTDIR/root/.ssh
	cat ~/.ssh/id_rsa.pub | sudo tee -a $ROOTDIR/root/.ssh/authorized_keys

	cat <<- ENDBASHRC | sudo tee -a  $ROOTDIR/root/.bashrc
		alias k='kubectl'
		alias ks='kubectl -n kube-system'
		alias kslogs='kubectl -n kube-system logs -l k8s-app=cilium --tail=-1'
		cilium_pod() {
		    kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath="{.items[?(@.spec.nodeName == \"\$1\")].metadata.name}"
		}
	ENDBASHRC

	cat <<- ENDFSTAB | sudo tee -a  $ROOTDIR/etc/fstab
		modules  /lib/modules   9p  trans=virtio,ro 0   0
	ENDFSTAB

	cat <<- ENDIFACES | sudo tee -a $ROOTDIR/etc/network/interfaces
		auto enp0s4
		iface enp0s4 inet dhcp
		auto enp0s3
		iface enp0s3 inet dhcp
	ENDIFACES
}

cleanup() {
	sudo umount $ROOTDIR
	sudo qemu-nbd -d $NBDDEV
}

if [ -f $ROOTIMG ]; then
	echo "file $ROOTIMG already exists: bailing out"
	exit 1
fi

mkimage
chrootconfig
miscconfig
cleanup
