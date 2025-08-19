#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Debug script for FastCS IOCs.
This script is used to parse the values.yaml file of a specified IOC and extract the command to run.
"""

import subprocess
from argparse import ArgumentParser
from pathlib import Path

from yaml import safe_load


def parse_args():
    parser = ArgumentParser(description="Debug script for FastCS IOCs")
    parser.add_argument(
        "ioc", help="folder in services to debug, e.g. bl47p-ea-fastcs-01"
    )
    parser.add_argument(
        "-n",
        "--namespace",
        help="Kubernetes namespace to use",
        required=True,
    )
    return parser.parse_args()


def extract_command_develop(ioc: str):
    ioc_values = Path(f"services/{ioc}/values.yaml")
    if not ioc_values.exists():
        print(f"Error: {ioc_values} does not exist")
        exit(1)

    values = safe_load(ioc_values.read_text())
    command = values.get("fastcs", {}).get("command", None)

    if command is None:
        print(f"Error: 'command' not found in {ioc_values}")
        exit(1)

    developerMode = values.get("fastcs", {}).get("developerMode", False)
    print(f"Developer Mode: {developerMode}")

    return command, developerMode


def run(cmd: str, allow_failure=False) -> bool:
    print(f"Running command: {cmd}")
    command = cmd.split()
    # Run the command and check for error
    result = subprocess.run(command)
    if result.returncode != 0 and not allow_failure:
        print(f"Command failed with return code {result.returncode}")
        exit(result.returncode)

    return result.returncode != 0


def main():
    args = parse_args()

    cmd_list, developerMode = extract_command_develop(args.ioc)
    # commands that have - will have modules with _ )
    cmd_list[0] = cmd_list[0].replace("-", "_")
    debug_args = " ".join(cmd_list)

    if developerMode:
        print(f"{args.ioc} is in developer mode, mounting code from the cluster ...")

        mount_point = Path("/tmp") / f"{args.ioc}-develop"
        mount_point.mkdir(parents=True, exist_ok=True)
        if mount_point.glob("*"):
            print("Error: Mount point {mount_point} is not empty")
            exit(1)

        run(f"pv-mounter mount {args.namespace} {args.ioc}-develop ./{args.ioc}")

        debugging = run(
            f"k exec -n {args.namespace} {args.ioc}-0 "
            f"-c fastcs -- ps aux | grep debugpy"
        )

        if debugging:
            print("Debugpy is already running, not starting it again.")
        else:
            debug_cmd = (
                f"python -Xfrozen_modules=off -m debugpy --listen 0.0.0.0:5678 "
                f"--wait-for-client --configure-subProcess true -m {debug_args}"
            )
            run(
                f"kubectl exec -tin {args.namespace} {args.ioc}-0 "
                f"-c fastcs -- {debug_cmd}"
            )

        # launch VS Code with the mounted workspace
        run(f"code {mount_point / 'workspaces' / '*'}")
    else:
        print(f"Running {args.ioc} in production mode")
        print("todo: attach a debugger")

    print("Port forwarding debug port. Hit Ctrl+C when done ...")
    run(f"kubectl port-forward -n {args.namespace} {args.ioc}-0 5678")

    print("Port forwarding stopped.")


if __name__ == "__main__":
    main()
