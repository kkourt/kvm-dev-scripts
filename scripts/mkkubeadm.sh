#!/bin/bash
# vim:noexpandtab

set -eu -o pipefail
set -x

CONF_DIR="$(realpath $(dirname "${BASH_SOURCE[0]}")/..)"
source $CONF_DIR/conf

mkkubeadm() {
	if [ -f "$KUBEADMIMG" ]; then
		set +x
		echo "file $KUBEADMIMG already exists. Bailing out"
		exit 1
	fi

	sudo modprobe nbd
	mkdir -p $KUBEADMDIR
    sudo qemu-img create -f qcow2 -b $(basename $ROOTIMG) $KUBEADMIMG
	sudo qemu-nbd -d $NBDDEV
	sudo qemu-nbd -c $NBDDEV $KUBEADMIMG
	sudo mount $NBDDEV $KUBEADMDIR
}

xinstall() {
	sudo chroot $KUBEADMDIR sh <<- ENDCHROOT
		set -e
		set -x

		cat <<-EOF | sudo tee /etc/sysctl.d/k8s.conf
			net.bridge.bridge-nf-call-ip6tables = 1
			net.bridge.bridge-nf-call-iptables = 1
			net.ipv4.ip_forward = 1
		EOF
		sudo sysctl --system

		sudo apt-get update && sudo apt-get install -y apt-transport-https curl gnupg
		curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
		cat <<-EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
			deb https://apt.kubernetes.io/ kubernetes-xenial main
		EOF
		sudo apt-get update

		sudo apt-get install -y docker.io

		sudo apt-get install -y kubelet kubeadm kubectl
		sudo apt-mark hold kubelet kubeadm kubectl

		#sudo systemctl enable docker.service
		#sudo systemctl daemon-reload
		#sudo systemctl restart kubelet
	ENDCHROOT
}

cleanup() {
	sudo umount $KUBEADMDIR
	sudo qemu-nbd -d $NBDDEV
}

if [ -f $KUBEADMIMG ]; then
	echo "file $KUBEADMIMG already exists: bailing out"
	exit 1
fi

mkkubeadm
xinstall
cleanup
