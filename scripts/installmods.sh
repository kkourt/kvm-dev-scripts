#!/bin/bash
# vim:noexpandtab

set -eu -o pipefail
set -x

CONF_DIR="$(realpath $(dirname "${BASH_SOURCE[0]}")/..)"
source $CONF_DIR/conf

sudo make -C $KERNEL_SOURCE INSTALL_MOD_PATH=$CONF_DIR/modules modules_install
