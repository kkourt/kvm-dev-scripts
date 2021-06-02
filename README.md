
First, we can edit the `conf` file for the various env variables.

# Images

Next, we need to build the root fs:

```
$ ./scripts/mkroot.sh
```


After that, we install `kubeadm`:
```
$ ./scripts/mkkubeadm.sh
```

Next, build the images for the two vms:
```
./scripts/mkkvm.sh 0
./scripts/mkkvm.sh 1
```

# Networking

(Proper scripts to be added)

There are multiple ways to setup networking. I opted for using a bridge device,
and attach a NIC for all VMs there. (to be automated)

```
# sudo ip link add kvm-br type bridge
# sudo ip addr add 10.33.33.100/24 dev kvm-br
```

And then, masquarade traffic from the VMs to the outside world

```
# sudo sh -c 'echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables'
# sudo modprobe br_netfilter
# sudo sysctl -w net.ipv4.ip_forward=1
# sudo iptables -t nat -A POSTROUTING  -o enxa0cec8e6e64c  -j MASQUERADE
# sudo iptables -A FORWARD -i enxa0cec8e6e64c -o kvm-br -m state --state RELATED,ESTABLISHED -j ACCEPT
# sudo iptables -A FORWARD -i  kvm-br -o enxa0cec8e6e64c -j ACCEPT
```

I use a simple `dnsmasq.conf`:

```
interface=kvm-br
port=0 # no dns

dhcp-option=option:router,10.33.33.100
dhcp-option=option:dns-server,8.8.8.8

dhcp-range=10.33.33.0,static
dhcp-host=52:54:00:12:34:01,kvm1,10.33.33.1
dhcp-host=52:54:00:12:34:02,kvm2,10.33.33.2

```

That I  run in debug mode:
```
sudo dnsmasq --conf-file=dnsmasq.conf -d
```

# Kernel image

The kernel image is expected to be in `KERNEL_SOURCE` in `conf`. Run
`./scripts/installmods.sh` to install modules.


# start vms

```
./scripts/runkvm 0
```

```
./scripts/runkvm 1
```


# Notes

`0` and `1` in `runkvm` and `mkkvm` scripts are used as indices to respective
bash arrays.
