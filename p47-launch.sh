#!/bin/bash
THIS_DIR=$(dirname "$(readlink -f "$0")")

# exit on error
set -e

# setup an ssh tunnel to the gateways and opis services. Use the beamline's
# fixed DNS names rather than the gateways/opis Services' LoadBalancer IPs:
# those IPs are only routed on the DLS internal network, and the kubectl
# lookup of them needs a cluster login.
#
# The gateways run with hostNetwork on the p47 beamline server, so its CA
# (9064) and PVA (9075) ports are the gateways themselves. The local ports
# must stay 9064 and 9075: a PVA name server's search reply names the server
# port, and the client connects to that port on the tunnel's local end.
gateways=p47-k8s-serv-01.diamond.ac.uk
opis=p47-opis.diamond.ac.uk
sock="$HOME/.ssh/cm-%r@%h:%p"
ssh -fNM -S "$sock" -L 9064:$gateways:9064 -L 9075:$gateways:9075 -L 8099:$opis:80 $HOSTNAME

# instruct shell to kill the ssh tunnel when done
SSH_PID=$(ssh -S "$sock" -O check $HOSTNAME 2>&1 | sed -n 's/.*pid=\([0-9]\+\).*/\1/p')
trap 'kill $SSH_PID' EXIT

# use the phoebus launcher script to start the GUI
$THIS_DIR/opi/phoebus-launch.sh -settings /workspace/settings.ini
