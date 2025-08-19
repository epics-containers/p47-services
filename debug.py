#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Debug script for FastCS IOCs.
This script is used to parse the values.yaml file of a specified IOC and extract the command to run.
"""

import os
import sys
from argparse import ArgumentParser
from pathlib import Path
from subprocess import PIPE, Popen
from subprocess import run as subprocess
from typing import Union

from yaml import safe_load


def report(message: str, color: str = "blue"):
    color_codes = {
        "blue": "\x1b[1;34m",
        "green": "\x1b[1;32m",
        "red": "\x1b[1;31m",
    }
    sys.stdout.write(f"{color_codes.get(color, color_codes['blue'])}{message}\x1b[0m\n")


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
        report(f"Error: {ioc_values} does not exist")
        exit(1)

    values = safe_load(ioc_values.read_text())
    command = values.get("fastcs", {}).get("command", None)

    if command is None:
        report(f"Error: 'command' not found in {ioc_values}")
        exit(1)

    developerMode = values.get("fastcs", {}).get("developerMode", False)
    report(f"Developer Mode: {developerMode}")

    return command, developerMode


def run(
    cmd: str, allow_failure=False, out=False, background=False
) -> Union[bool, str, int]:
    report(f"Running command: {cmd}", color="green")
    command = cmd.split()

    if background:
        result = Popen(command)
        report(f"Command started in background with PID {result.pid}")
        return result.pid
    elif out:
        result = subprocess(command, stdout=PIPE, stderr=PIPE)
    else:
        result = subprocess(
            command, stdout=sys.stdout, stderr=sys.stderr, stdin=sys.stdin
        )
    if result.returncode != 0 and not allow_failure:
        report(f"Command failed with return code {result.returncode}")
        exit(result.returncode)

    if out:
        return result.stdout.decode() if result.stdout else ""
    else:
        return result.returncode != 0


def do_developer_mode(ioc: str, namespace: str, debug_args: str):
    """
    Handle developer mode for the specified IOC.

    Mount the source locally, open it in vscode and start debugpy in
    the correct pod.
    """
    report(f"{ioc} is in developer mode, mounting code from the cluster ...")

    mount_point = Path(f"{ioc}-develop")
    mount_point.mkdir(parents=True, exist_ok=True)
    if list(mount_point.glob("*")):
        report(f"Mount point {mount_point} already mounted, skipping mount.")
    else:
        run(f"pv-mounter mount {namespace} {ioc}-develop {mount_point}")

    # launch VS Code with the mounted workspace
    report(f"Launching VS Code with mounted workspace {mount_point} ...")
    run(f"code {mount_point / 'workspaces' / '*'}")

    report("Checking if debugpy is already running ...")
    out = run(f"kubectl exec -n {namespace} {ioc}-0 -- ps aux", out=True)

    if "debugpy" in str(out):
        report("Debugpy is already running, not starting it again.")
    else:
        report("Launching debugpy, attach a debug client to start the IOC ...")
        debug_cmd = (
            f"python -Xfrozen_modules=off -m debugpy --listen 0.0.0.0:5678 "
            f"--wait-for-client --configure-subProcess true -m {debug_args}"
        )
        run(f"kubectl exec -tin {namespace} {ioc}-0 -c fastcs -- {debug_cmd}")


def do_production_mode(ioc: str, namespace: str):
    """
    Handle production mode for the specified IOC.
    This is a placeholder function for future implementation.
    """
    report(f"Running {ioc} in production mode with args: {debug_args}")


def main():
    args = parse_args()

    os.chdir(Path(__file__).parent)

    cmd_list, developerMode = extract_command_develop(args.ioc)
    # commands that have - will have modules with _ )
    cmd_list[0] = cmd_list[0].replace("-", "_")
    debug_args = " ".join(cmd_list)

    report("Port forwarding debug port. Hit Ctrl+C when done ...")
    pid = run(
        f"kubectl port-forward -n {args.namespace} {args.ioc}-0 5678", background=True
    )

    try:
        if developerMode:
            do_developer_mode(args.ioc, args.namespace, debug_args)
        else:
            report(f"Running {args.ioc} in production mode")
            report("todo: attach a debugger")
    finally:
        if pid:
            run(f"kill {pid}")
            report(f"Port forwarding stopped for PID {pid}.")


if __name__ == "__main__":
    main()
