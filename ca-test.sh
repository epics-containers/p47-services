#!/bin/bash

# set up the environment for caget/pvxget for this shell
export EPICS_CA_NAME_SERVERS=localhost:9064
export EPICS_PVA_NAME_SERVERS=localhost:9075
export EPICS_CA_MAX_ARRAY_BYTES=6000000
export EPICS_PVA_MAX_ARRAY_BYTES=6000000
export EPICS_CA_AUTO_ADDR_LIST=NO
export EPICS_PVA_AUTO_ADDR_LIST=NO

# demonstrate caget works
caget BL47P-EA-DCAM-01:UPTIME
caget BL47P-EA-DET-01:DET:ArrayCounter_RBV
# demonstrate pvxget works
pvxget BL47P-EA-DET-01:TX:PVA | grep uncompressedSize