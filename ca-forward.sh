#!/bin/bash
ssh -f -L 9064:172.23.168.161:9064 -L 9075:172.23.168.161:9075 hgv27681@bl46p-ea-serv-01 -N

# This is where:
# - gateways loadbalancer IP is: 172.23.168.161
# - my home PC is pc0116 (but you could also pick a PC in science network to avoid firewall issues)
# - 9064, 9075, and 10080 are the ports used by the gateways (ca, pva) and demo.bob OPI respectively.
