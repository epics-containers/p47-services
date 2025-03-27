#!/bin/bash

# a bash script to source in order to set up your command line to in order
# to work with the p47 IOCs and Services.

# check we are sourced
if [ "$0" = "$BASH_SOURCE" ]; then
    echo "ERROR: Please source this script"
    exit 1
fi

echo "Loading environment for p47 IOC Instances and Services ..."

#### SECTION 1. Environment variables ##########################################

export EC_CLI_BACKEND="K8S"
# the namespace to use for kubernetes deployments
export EC_TARGET=p47-beamline
# the git repo for this project
export EC_SERVICES_REPO=https://github.com/epics-containers/p47-services
# declare your centralised log server Web UI
export EC_LOG_URL="https://graylog2.diamond.ac.uk/search?rangetype=relative&fields=message%2Csource&width=1489&highlightMessage=&relative=172800&q=pod_name%3A{service_name}*"

#### SECTION 2. Install ec #####################################################

# check if epics-containers-cli (ec command) is installed
if ! ec --version &> /dev/null; then
    echo "ERROR: Please set up a virtual environment and: 'pip install edge-containers-cli'"
    return 1
fi

# enable shell completion for ec commands
source <(ec --show-completion ${SHELL})


#### SECTION 3. Configure Kubernetes Cluster ###################################


# the following configures kubernetes inside DLS.

module unload pollux > /dev/null
module load pollux > /dev/null
# set the default namespace for kubectl and helm (for convenience only)
kubectl config set-context --current --namespace=p47-beamline
# make sure the user has provided credentials
kubectl version


# enable shell completion for k8s tools
if [ -n "$ZSH_VERSION" ]; then SHELL=zsh; fi
source <(helm completion $(basename ${SHELL}))
source <(kubectl completion $(basename ${SHELL}))

# Additional settings for routing to p47-gateways from different networks
export EPICS_CA_NAME_SERVERS=localhost:9064
export EPICS_PVA_NAME_SERVERS=localhost.diamond.ac.uk:9065

# localhost requires setting up a ssh tunnel to the actual destination
# we do this to get through the VPN port restrictions. If you were on a
# DLS network, you could use p47-ea-serv-01 instead of localhost
# and not require the tunnel
#
# also note that no changes required for using this in the controls dev network
# because AUTO_ADDR_LIST is still enabled.
#
# to set up the tunnel:
# ssh -f -L 6443:api.pollux.diamond.ac.uk:6443 -L 9064:bl47p-ea-serv-01.diamond.ac.uk:9064 -L 9065:bl47p-ea-serv-01.diamond.ac.uk:9065  hgv27681@pc0116.cs.diamond.ac.uk -N

