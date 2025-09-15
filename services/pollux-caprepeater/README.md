# carepeater DeamonSet for pollux

This deploys a DaemonSet running [carepeater](https://epics.anl.gov/base/R3-14/12-docs/CAref.html#Repeater).

It runs on all IOC nodes in the pollux cluster and supplies carepeater for all test beamlines in pollux.

Note: to make this more like real beamlines we should just have one of these per test/training beamline, and share affinity and tolerations from the root values.yaml.

But doing it this way was more fun!
