#!/bin/bash

# Forward the p47 gateways' CA (9064) and PVA (9075) ports to localhost, so
# that caget/pvxget etc. on this machine reach the p47 PVs with:
#
#   export EPICS_CA_NAME_SERVERS=localhost:9064
#   export EPICS_PVA_NAME_SERVERS=localhost:9075
#
# (environment.sh and ca-test.sh set these). The tunnel uses the same fixed
# DNS name as p47-launch.sh, so it works on site and over the VPN.
#
# Usage:
#   ./ca-forward.sh        open the tunnel in the background (or report it is open)
#   ./ca-forward.sh stop   close it

# The gateways run with hostNetwork on the p47 beamline server. The local
# ports must stay 9064 and 9075: a PVA name server's search reply names the
# server port, and the client connects to that port on the tunnel's local end.
gateways=p47-k8s-serv-01.diamond.ac.uk
sock="$HOME/.ssh/p47-ca-forward.sock"

if [ "$1" = "stop" ]; then
    ssh -S "$sock" -O exit "$HOSTNAME"
    exit
fi

if ssh -S "$sock" -O check "$HOSTNAME" 2> /dev/null; then
    echo "p47 CA/PVA tunnel is already open"
    exit 0
fi

ssh -fNM -S "$sock" -o ExitOnForwardFailure=yes \
    -L 9064:$gateways:9064 -L 9075:$gateways:9075 "$HOSTNAME"
echo "p47 CA/PVA tunnel open on localhost:9064 (CA) and localhost:9075 (PVA)"
echo "close it with: $0 stop"
