#!/bin/bash

# Check that CA and PVA clients on this machine reach live p47 PVs through
# the tunnel that ca-forward.sh opens. The tunnel is left open afterwards;
# close it with ./ca-forward.sh stop

THIS_DIR=$(dirname "$(readlink -f "$0")")

# exit on error
set -e

"$THIS_DIR/ca-forward.sh"

# talk only to the tunnelled gateways, never broadcast
export EPICS_CA_NAME_SERVERS=localhost:9064
export EPICS_PVA_NAME_SERVERS=localhost:9075
export EPICS_CA_MAX_ARRAY_BYTES=6000000
export EPICS_PVA_MAX_ARRAY_BYTES=6000000
export EPICS_CA_AUTO_ADDR_LIST=NO
export EPICS_PVA_AUTO_ADDR_LIST=NO
export EPICS_CA_ADDR_LIST=
export EPICS_PVA_ADDR_LIST=

# demonstrate caget works
caget BL47P-EA-DCAM-01:UPTIME
caget BL47P-EA-DET-01:DET:ArrayCounter_RBV
# demonstrate pvxget works
pvxget BL47P-EA-DCAM-01:UPTIME
pvxget BL47P-EA-DET-01:TX:PVA | grep uncompressedSize
