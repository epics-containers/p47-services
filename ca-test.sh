#!/bin/bash

# set up the environment for caget for this shell
export EPICS_CA_NAME_SERVERS=localhost:9064
# or do this with no ssh tunnel (but firewall issues may occur)
# export EPICS_CA_NAME_SERVERS=172.23.168.161:9064
export EPICS_CA_AUTO_ADDR_LIST=NO

# demonstrate caget works
caget BL47P-EA-DCAM-01:UPTIME
caget BL47P-EA-DET-01:DET:ArrayCounter_RBV
