#!/bin/bash

# EPICS_PVA_AUTO_ADDR_LIST=NO implies we are running in cluster network
#   in this cast we should use the IP list from get_ioc_ips.py
# EPICS_PVA_AUTO_ADDR_LIST=YES implies we are running in hostNetwork
#   in this case we can broadcast to find local subnet PVs

THIS=$(realpath $(dirname $0))

# IP lists for IOCS (blank if get_ioc_ips.py fails)
if [[ ${HOST_NETWORK} == "NO" ]]; then
  export IPS="$(python3 /config/get_ioc_ips.py)"
  export EPICS_PVA_ADDR_LIST=${IPS:-127.0.0.1}
else
  export EPICS_PVA_ADDR_LIST=${EPICS_PVA_ADDR_LIST:-127.0.0.1}
fi

# PORTS for CA and PVA
export CA_SERVER_PORT=${CA_SERVER_PORT:-5064}
export PVA_SERVER_PORT=${PVA_SERVER_PORT:-5075}

# DEBUGGING
CA_DEBUG=${CA_DEBUG:-0}
PVA_DEBUG=${PVA_DEBUG:-0}

# AUTO_ADDR_LIST
if [[ ${EPICS_PVA_ADDR_LIST} == "YES" ]]; then
  export AUTO_ADDR_LIST=true
else
  export AUTO_ADDR_LIST=false
fi

# fix up the templated pva gateway config
cat ${THIS}/pvagw.template |
  sed \
    -e "s/PVA_ADDR_LIST/${EPICS_PVA_ADDR_LIST}/" \
    -e "s/PVA_SERVER_PORT/${PVA_SERVER_PORT}/" \
    -e "s/PVA_AUTO_ADDR_LIST/${AUTO_ADDR_LIST}/" \
    > /tmp/pvagw.config

# background the PVA Gateway
pvagw /tmp/pvagw.config
