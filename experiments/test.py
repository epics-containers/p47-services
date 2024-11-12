#!/usr/bin/env python

"""
Prints out some information about the pods in a namespace
"""

import argparse

from kubernetes import client, config


def get_ioc_ips(v1: client.CoreV1Api):
    """Get the list cluster IPs of IOCs running in a namespace

    Args:
        v1: kubernetes client
        namespace: namespace to get the IOCs from
    """
    ips = set()

    # get the current namespace
    ns_path = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
    with open(ns_path) as f:
        current_namespace = f.read().strip()

    # get the pods in the namespace
    ret = v1.list_namespaced_pod(current_namespace)
    for pod in ret.items:
        print(pod.metadata.name, pod.status.pod_ip)
        if "is_ioc" in pod.metadata.labels:
            ips.add(pod.status.pod_ip)

    return ips


def main():
    args = parse_args()

    # configure K8S and make a Core API client
    config.load_incluster_config()
    v1 = client.CoreV1Api()

    ips = get_ioc_ips(v1)
    ipstr = " ".join(ips)

    command = f'/epics/ca-gateway/bin/linux-x86_64/gateway -sport {args.port} -cip "{ipstr}" -pvlist /config/pvlist -access /config/access -log /dev/stdout -debug 1'

    # print(f"Running command: {command}")
    # subprocess.run(["bash", "-c", command], check=True)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5064)
    return parser.parse_args()


if __name__ == "__main__":
    main()
