#!/bin/bash

THIS_DIR="$(dirname "$(readlink -f "$0")")"

if [[ -z ${EPICS_CA_ADDR_LIST} ]]; then
  echo "EPICS_CA_ADDR_LIST is not set, discovering IOCs DNS names in the namespace"
  export EPICS_CA_ADDR_LIST=$(python3 ${THIS_DIR}/get_ioc_list.py --namespace hgv27681 --dns-names)
fi

if [[ -z ${EPICS_PVA_ADDR_LIST} ]]; then
  echo "EPICS_PVA_ADDR_LIST is not set, discovering IOCs DNS names in the namespace"
  export EPICS_PVA_ADDR_LIST="$(python3 ${THIS_DIR}/get_ioc_list.py --namespace hgv27681 --dns-names)"
fi

echo "Using EPICS_CA_ADDR_LIST: ${EPICS_CA_ADDR_LIST}"
echo "Using EPICS_PVA_ADDR_LIST: ${EPICS_PVA_ADDR_LIST}"
