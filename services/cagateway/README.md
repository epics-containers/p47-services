# To add a CA Gateway to talk to non-network host IOCs:

```bash
module load pollux
helm upgrade --install -n p47-beamline cagateway services/cagateway
```

# To test the CA Gateway:

- Go check what the IP address of the the cagateway-service is ...
- then
```bash
export EPICS_CA_ADDR_LIST=172.23.168.193:9064
caget XXX
```


