#!/bin/bash
THIS_DIR=$(dirname "$(readlink -f "$0")")

# exit on error
set -e

# load the argus to talk to user's FEDID namespace in the Argus cluster
module unload ec
module unload argus
module load pollux

# setup an ssh tunnel to the gateways and opis services
gateways=$(kubectl get svc -n p47-beamline bl47p-gateways --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
opis=$(kubectl get svc -n p47-beamline epics-opis --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
sock="$HOME/.ssh/cm-%r@%h:%p"
ssh -fNM -S "$sock" -L 9064:$gateways:9064 -L 9075:$gateways:9075 -L 8099:$opis:80 $HOSTNAME

# instruct shell to kill the ssh tunnel when done
SSH_PID=$(ssh -S "$sock" -O check $HOSTNAME 2>&1 | sed -n 's/.*pid=\([0-9]\+\).*/\1/p')
trap 'kill $SSH_PID' EXIT

# use the phoebus launcher script to start the GUI
$THIS_DIR/opi/phoebus-launch.sh -settings /workspace/settings.ini
