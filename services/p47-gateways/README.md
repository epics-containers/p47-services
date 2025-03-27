# gateways

PVA and CA gateway services running in two containers in a single pod, with single service exposing both on different ports.

To deploy this (for now - eventually we should have a oci helm chart for these):

```bash
helm upgrade --install gateways services/gateways
```