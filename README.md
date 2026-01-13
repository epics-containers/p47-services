# p47 IOC Instances and Services

This repository holds the a definition of p47 IOC Instances and services. Each sub folder of the `services` directory contains a helm chart for a specific service or IOC. The corresponding deployments repo can be found at [https://gitlab.diamond.ac.uk/controls/containers/beamline/p47-deployment].

## Using pre-commit hooks

Pre commit hooks will validate the synoptic and additional soft support if present. To install pre-commit hooks run:

```bash
uvx pre-commit install
```

To force execution of the pre-commit hooks on all files run:

```bash
uvx pre-commit run --all-files
```
