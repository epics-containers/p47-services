# p47 IOC Instances and Services

This repository holds the a definition of p47 IOC Instances and services. Each sub folder of the `services` directory contains a helm chart for a specific service or IOC.


The `opi` directory contains the settings for the OPI client to connect to the services and a synoptic.

The opi files try to connect to localhost for the CA and PVA name servers. This means you need to forward the ports from the host to your local machine.

Use one of the following commands to forward the ports:

```bash
# this seems really flakey for some reason and is not availble on VPN without
# setting up kubectl
kubectl port-forward -n p47-beamline deploy/bl47p-gateways 8064:9064 8075:9075

# this works on the VPN and anywhere in DLS and avoids issues with firewalls
ssh -f -L 9064:172.23.168.161:9064 -L 9075:172.23.168.161:9075 hgv27681@bl49p-ea-serv-01 -N