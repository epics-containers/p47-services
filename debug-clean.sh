#!/bin/bash

# get rid of backgrounded port-forward processes
killall kubectl

# get rid of exposer pods - this will effectively unmount the sshfs volumes
pods=$(kubectl get -n p47-beamline pods -o name | grep volume-exposer)
kubectl delete -n p47-beamline $pods

