Shared Services
===============

There are a number of helm charts that all domains will likely require. At present these are as follows:

- **epics-pvcs**: sets up the PVCs that all IOCs may use. These should be set up once and not deleted as they hold data for IOCs. All of the PVCs have a folder hierarchy with the names of IOCs at the root.

  - autosave data: for IOCs that support autosave. This is separate from IOC helm charts so that it can survive deletion and re-creation of an IOC.

  - opis: all the OPI files for engineering screens that an IOC supplies are saved here. This is stored in a single PVC so that the opis service can publish them over http for access by an OPI client.

- **epics-opis**: installs the web server that shares the engineering screens published by each IOC. The structure is two deep only: IOC names as folders at the root containing all the IOCs OPI files in a flat list.

Deploy these charts to the domain cluster using by setting up your cluster and namespace connection using environment.sh and then executing the following commands (requires that edge-containers-cli is installed):

```bash
ec list # lists the latest versions of all services
ec deploy epics-pvcs VERSION
ec deploy epics-opis VERSION
```
