# To add a CA Gateway to talk to non-network host IOCs:

```bash
module load pollux
helm upgrade --install -n p47-beamline cagateway services/cagateway
```

# To test the CA Gateway:

Go check what the IP address of the the cagateway-service is ...

```bash
$ k get -n p47-beamline service/cagateway                                                                                                                                                                                                      [12:29:01]
NAME        TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                         AGE
cagateway   LoadBalancer   10.111.111.235   172.23.168.193   9064:31852/TCP,9064:31852/UDP   3m50s
```

then use the ipaddress and port to set EPICS_CA_ADDR_LIST ...

```bash
export EPICS_CA_ADDR_LIST=172.23.168.193:9064
caget XXX
```


