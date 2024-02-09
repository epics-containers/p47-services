BL47P Training Beamline
=======================

Describes the K8S services that are deployed to the beamline local cluster.

These should be deployed using edge-containers-cli.

For a manual deployment for test purposes:

```bash
# this example for bl47p-ea-test-01
./update-helm
helm upgrade --install bl47p-ea-test-01 services/bl47p-ea-test-01/
```
