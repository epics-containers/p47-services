#!/bin/bash
THIS_DIR=$(dirname "$(readlink -f "$0")")

# exit on error
set -e

# load the argus to talk to user's FEDID namespace in the Argus cluster
module load pollux

# setup an ssh tunnel to the gateways and opis services
gateways=$(kubectl get svc -n p47-beamline p47-gateways --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
opis=$(kubectl get svc -n p47-beamline epics-opis --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
ssh -L 9064:$gateways:9064 -L 9075:$gateways:9075 -L 8099:$opis:80 $HOSTNAME -N &
SSH_PID=$!

# use the phoebus launcher script to start the GUI
$THIS_DIR/opi/phoebus-launch.sh

# kill the ssh tunnel when done
kill $SSH_PID
