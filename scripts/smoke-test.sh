#!/bin/bash
#
# Check that the p47 beamline works end to end, read-only.
#
#   scripts/smoke-test.sh [options] [namespace]
#
# Point KUBECONFIG (or --pod-cluster) at pollux, where the beamline Pods run,
# and --argocd-kubeconfig at argus, where the Argo CD Applications live. Both
# kubeconfigs are given to whoever operates p47; see the README.
#
# 1. waits for the root Application and every child Application to be Synced
#    and Healthy, and for every Pod to be Ready
# 2. reads each IOC's representative PVs twice, independently: once directly
#    on the beamline host (exec into the IOC's own hostNetwork Pod, no
#    gateway involved) and once through the p47-epics-gateways gateway (exec
#    into the p47-blueapi Pod, which already points at it)
# 3. checks blueapi's /healthz, through its oauth2-proxy
# 4. checks that the OPI screens are served over plain HTTP
#
# All of the above is unattended and mutates nothing. A fifth, optional step
# needs a person: a device-code login against the real DLS Keycloak
# (identity.diamond.ac.uk), using blueapi's own `login` command, followed by
# a small test plan. It only runs with --login, or when you answer yes to
# the prompt; otherwise it prints what it would do and skips cleanly. This
# script never attempts that login itself and never touches auth config.
#
# bl47p-synoptic is a known, parked failure (services-template-helm#145: its
# init container can't apt-get as a non-root user, so it never leaves
# Init:CrashLoopBackOff and never gets the status PVs a synoptic normally
# serves). This script reports it, every time, as an expected failure, and
# does not let it block step 1 or fail the run. Use --strict to turn expected
# failures back into real ones, e.g. to confirm a fix.
#
# bl47p-ea-fastcs-01 is a dev/example service on a feature branch
# (podbench-hotfix-claim), not part of the physical beamline, and it has no
# EPICS PVs at all: it is excluded from the PV checks (but still has to be a
# healthy Pod, like everything else, in step 1).
#
# Now that the gateway runs on the same host as the IOCs (services main,
# commit 5afcf20), a CA client can occasionally see one of these PVs
# advertised twice and print a libca "duplicate process variable name"
# warning. That is benign - the read still succeeds - so this script never
# treats it as a failure; it is filtered out of PASS/FAIL lines and reported
# once as a note instead.
#
# The exit status is 0 only when every non-excluded, non-expected check
# passes. The optional login/plan step never affects the exit status.

set -euo pipefail

bl_prog=smoke-test.sh
bl_env_hint=""
# shellcheck source-path=SCRIPTDIR source=lib/cluster.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/cluster.sh"

die() {
    bl_error "$@" || exit 1
}

usage() {
    cat <<EOF
Usage: scripts/smoke-test.sh [options] [namespace]

Check the p47 beamline end to end: Argo CD apps and pods, IOC PVs (directly
and through the gateway), blueapi's healthz, and the OPIs. Read-only.

Arguments:
  namespace             namespace of the p47 beamline (default: p47-beamline)

Options:
  -n, --namespace NS     same as the namespace argument
      --argocd-context CONTEXT
                          context for Application checks (default: current)
      --argocd-kubeconfig PATH
                          kubeconfig for Application checks (default: current
                          KUBECONFIG); accepts a colon-separated list of files
      --pod-cluster PATH  kubeconfig for Pod/Service checks and PV reads
                          (default: current KUBECONFIG); uses its current
                          context
  -t, --timeout SECS     how long to wait for the apps and pods (default: 300)
      --no-wait           skip the wait, e.g. for a beamline already up
      --strict             do not excuse known/expected failures (see the
                          script header); use this to confirm a fix
      --login              run the optional device-code login and test plan
                          (needs a person at the keyboard; see the header)
      --no-login            never run it, and never prompt either
      --blueapi-url URL   the blueapi oauth2-proxy's public URL, for --login
                          (default: https://p47-blueapi.diamond.ac.uk)
      --login-plan NAME   plan to submit after login (default: count)
      --login-params JSON parameters for that plan (default: a short count
                          on a simulated detector; check the device name
                          with the blueapi CLI first - see the header)
  -h, --help              show this help
EOF
}

namespace=""
argocd_context=""
argocd_kubeconfig=${KUBECONFIG:-$HOME/.kube/config}
pod_kubeconfig=${KUBECONFIG:-$HOME/.kube/config}
timeout=300
wait=true
strict=false
login=""
blueapi_url="https://p47-blueapi.diamond.ac.uk"
login_plan="count"
login_params='{"detectors": ["bl47p_ea_simdet_01"], "num": 1}'

# the root app, as p47-deployment's apps.yaml names it
root_app=p47
# the pod that runs the through-the-gateway PV checks and the login step
check_pod=p47-blueapi-0
check_container=blueapi
# printed when a check fails
troubleshoot_url=https://github.com/epics-containers/p47-services#smoke-test

# known, parked failures: a substring of a not_ready() line, mapped to why
# it is excused. --strict turns these back into ordinary failures.
declare -A known_issues=(
    [bl47p-synoptic]="services-template-helm#145: Init:CrashLoopBackOff (techui-builder can't apt-get as non-root); parked, no ETA"
)

# IOCs with no EPICS PVs to check at all (still checked for Pod health)
declare -A excluded_iocs=(
    [bl47p-ea-fastcs-01]="dev/example service on branch podbench-hotfix-claim, not part of the physical beamline"
)

# the PVs to read from each IOC, by release name. The default when an IOC
# is not listed here is <IOC_NAME>:UPTIME from devIocStats, which every IOC
# below also has; the entries here add one PV that exercises real hardware
# or a real detector, not just liveness.
declare -A ioc_pvs=(
    [bl47p-mo-ioc-01]="BL47P-MO-IOC-01:UPTIME BL47P-MO-MAP-01:STAGE:X.RBV"
    [bl47p-ea-dcam-01]="BL47P-EA-DCAM-01:UPTIME BL47P-EA-DET-01:DET:Acquire"
    [bl47p-ea-dcam-02]="BL47P-EA-DCAM-02:UPTIME BL47P-EA-DET-02:DET:Acquire"
    [bl47p-ea-simdet-01]="BL47P-EA-SIMDET-01:UPTIME BL47P-EA-SIMDET-01:DET:Acquire"
    [bl47p-ea-simdet-02]="BL47P-EA-SIMDET-02:UPTIME BL47P-EA-SIMDET-02:DET:Acquire"
    [bl47p-ea-simdet-03]="BL47P-EA-SIMDET-03:UPTIME BL47P-EA-SIMDET-03:DET:Acquire"
)

# a libca warning that only shows up because the gateway now runs on the
# same host as the IOCs; benign (the read still succeeds), never a failure
benign_ca_warning='[Dd]uplicate process variable|[Ii]dentical process variable'

# the value of an option, or an error when it is missing
need_value() {
    [[ $2 -ge 2 && -n $3 ]] || die "$1 needs a value. See --help."
}

while (($#)); do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    -n | --namespace)
        need_value "$1" $# "${2:-}"
        namespace=$2
        shift 2
        ;;
    -t | --timeout)
        need_value "$1" $# "${2:-}"
        timeout=$2
        shift 2
        ;;
    --argocd-context)
        need_value "$1" $# "${2:-}"
        argocd_context=$2
        shift 2
        ;;
    --argocd-kubeconfig)
        need_value "$1" $# "${2:-}"
        argocd_kubeconfig=$2
        shift 2
        ;;
    --pod-cluster)
        need_value "$1" $# "${2:-}"
        [[ $2 != -* ]] || die "$1 needs a kubeconfig path. See --help."
        pod_kubeconfig=$2
        shift 2
        ;;
    --no-wait)
        wait=false
        shift
        ;;
    --strict)
        strict=true
        shift
        ;;
    --login)
        login=yes
        shift
        ;;
    --no-login)
        login=no
        shift
        ;;
    --blueapi-url)
        need_value "$1" $# "${2:-}"
        blueapi_url=$2
        shift 2
        ;;
    --login-plan)
        need_value "$1" $# "${2:-}"
        login_plan=$2
        shift 2
        ;;
    --login-params)
        need_value "$1" $# "${2:-}"
        login_params=$2
        shift 2
        ;;
    -*)
        die "unknown option '$1'. See --help."
        ;;
    *)
        [[ -z $namespace ]] || die "unexpected argument '$1'. See --help."
        namespace=$1
        shift
        ;;
    esac
done

[[ $timeout =~ ^[0-9]+$ ]] || die "--timeout must be a number of seconds"

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

# a heading for each numbered step
step() {
    echo
    log "== step $*"
}

# print each line of stdin indented
indent() {
    local line
    while IFS= read -r line; do echo "  $line"; done
}

namespace=${namespace:-p47-beamline}
# Keep the caller's connection for Argo CD; all other kubectl calls, including
# the shared namespace checks and the PV reads, use the workload connection.
export KUBECONFIG=$pod_kubeconfig
bl_check_namespace "$namespace" || exit 1
log "connected with context '$bl_context'"

failures=0
warnings=0

# print "PASS $*" or "FAIL $*"/"WARN $*" and count it
check() {
    local rc=$1
    shift
    if ((rc == 0)); then
        log "PASS $*"
    else
        log "FAIL $*"
        failures=$((failures + 1))
    fi
}

warn() {
    log "WARN $*"
    warnings=$((warnings + 1))
}

# run a command, retrying while it fails, filtering the benign duplicate-PV
# warning out of its stderr into a note instead of treating it as a failure
#   run_with_retry LABEL -- command args...
run_with_retry() {
    local label=$1 attempts=${RETRY_ATTEMPTS:-6} delay=${RETRY_DELAY:-5}
    shift
    [[ ${1:-} == -- ]] && shift
    local attempt out err err_file rc
    err_file=$(mktemp)
    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if out=$("$@" 2>"$err_file"); then
            rc=0
        else
            rc=$?
        fi
        err=$(cat "$err_file")
        if [[ $err =~ $benign_ca_warning ]]; then
            log "note: $label: benign duplicate-PV warning, ignored (the gateway now runs on the same host as the IOCs)"
            err=$(grep -vE "$benign_ca_warning" <<<"$err" || true)
        fi
        if ((rc == 0)); then
            [[ -z $err ]] || log "note: $label: $err"
            check 0 "$label = $(tr '\n' ' ' <<<"$out" | sed 's/  */ /g; s/ *$//')"
            rm -f "$err_file"
            return 0
        fi
        if ((attempt < attempts)); then
            ((attempt > 1)) || log "$label: not yet (${err:-exit $rc}). Retrying for up to $((attempts * delay))s"
            sleep "$delay"
        fi
    done
    check 1 "$label: ${err:-exit $rc}"
    rm -f "$err_file"
    return 1
}

# ---------------------------------------------------------------------------
# 1. wait for the apps and pods

# Only Application lookups use the Argo CD connection. Pod checks use
# --pod-cluster when supplied, otherwise the caller's current cluster.
argocd_kubectl() (
    if [[ -n $argocd_kubeconfig ]]; then
        export KUBECONFIG=$argocd_kubeconfig
    fi
    local args=()
    [[ -z $argocd_context ]] || args+=(--context "$argocd_context")
    kubectl "${args[@]}" "$@"
)

# print what is not ready yet, one item per line; nothing when all is ready
not_ready() {
    local root children apps pods

    root=$(argocd_kubectl get application "$root_app" -n "$namespace" \
        -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null) || {
        echo "root app '$root_app' (not found)"
        return
    }
    [[ $root == "Synced Healthy" ]] || echo "root app '$root_app' ($root)"

    children=$(argocd_kubectl get application "$root_app" -n "$namespace" \
        -o jsonpath='{range .status.resources[?(@.kind=="Application")]}{.name}{"\n"}{end}')
    if [[ -z $children ]]; then
        echo "child apps (none listed yet)"
        return
    fi
    apps=$(argocd_kubectl get applications -n "$namespace" \
        -o jsonpath='{range .items[*]}{.metadata.name} {.status.sync.status} {.status.health.status}{"\n"}{end}')
    local name status
    while read -r name; do
        status=$(awk -v n="$name" '$1 == n {print $2, $3}' <<<"$apps")
        [[ $status == "Synced Healthy" ]] || echo "app $name (${status:-not created})"
    done <<<"$children"

    # a pod is done when it succeeded, or runs with every container ready
    pods=$(kubectl get pods -n "$namespace" \
        -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase} {.status.containerStatuses[*].ready}{"\n"}{end}')
    local phase ready
    while read -r name phase ready; do
        [[ -n $name ]] || continue
        case $phase in
        Succeeded) ;;
        Running) [[ " $ready " != *" false "* && -n $ready ]] || echo "pod $name (not ready)" ;;
        *) echo "pod $name ($phase)" ;;
        esac
    done <<<"$pods"
}

# split not_ready()'s lines into "still blocking" and "excused by
# known_issues" (unless --strict), printing the excused ones once as notes
classify_pending() {
    local pending=$1 line key matched
    unexpected=()
    expected=()
    while IFS= read -r line; do
        [[ -n $line ]] || continue
        matched=""
        if ! $strict; then
            for key in "${!known_issues[@]}"; do
                [[ $line == *"$key"* ]] || continue
                matched=$key
                break
            done
        fi
        if [[ -n $matched ]]; then
            expected+=("$line (expected: ${known_issues[$matched]})")
        else
            unexpected+=("$line")
        fi
    done <<<"$pending"
}

if $wait; then
    step "1/4: wait for the apps and pods"
    log "waiting up to ${timeout}s for the apps and pods in '$namespace'"
    deadline=$((SECONDS + timeout))
    last="" reported_expected=false
    while true; do
        pending=$(not_ready)
        classify_pending "$pending"
        if ((${#expected[@]})) && ! $reported_expected; then
            log "known issue(s), not blocking:"
            printf '%s\n' "${expected[@]}" | indent
            reported_expected=true
        fi
        if ((${#unexpected[@]} == 0)); then
            break
        fi
        if ((SECONDS >= deadline)); then
            log "timed out. Still not ready:"
            printf '%s\n' "${unexpected[@]}" | indent
            log "see $troubleshoot_url"
            exit 1
        fi
        current=$(printf '%s\n' "${unexpected[@]}")
        if [[ $current != "$last" ]]; then
            log "waiting for ${#unexpected[@]} item(s):"
            printf '%s\n' "${unexpected[@]}" | head -15 | indent
            last=$current
        fi
        sleep 10
    done
    if ((${#expected[@]})); then
        warnings=$((warnings + ${#expected[@]}))
        log "all other apps are Synced and Healthy, and all other pods are Ready"
    else
        log "all apps are Synced and Healthy, and all pods are Ready"
    fi
else
    step "1/4: skipped (--no-wait)"
fi

# ---------------------------------------------------------------------------
# 2. read each IOC's PVs, directly and through the gateway

step "2/4: read each IOC's PVs directly, and through the gateway"

kubectl get pod "$check_pod" -n "$namespace" >/dev/null 2>&1 ||
    die "no pod '$check_pod' in namespace '$namespace'"

ca_get_py='
import sys
from aioca import caget
import asyncio
async def main():
    print(await caget(sys.argv[1], timeout=5))
asyncio.run(main())
'
pva_get_py='
import sys
from p4p.client.thread import Context
with Context("pva") as ctx:
    print(ctx.get(sys.argv[1], timeout=5))
'

iocs=$(kubectl get pods -n "$namespace" -l ioc=true \
    -o jsonpath='{range .items[*]}{.metadata.labels.app}{"\n"}{end}' | sort -u)
[[ -n $iocs ]] || die "no IOC pods (label ioc=true) in namespace '$namespace'"

checked_any=false
while read -r ioc; do
    [[ -n $ioc ]] || continue
    if [[ -n ${excluded_iocs[$ioc]:-} ]]; then
        warn "$ioc: excluded from PV checks (${excluded_iocs[$ioc]})"
        continue
    fi
    if [[ -n ${known_issues[$ioc]:-} ]] && ! $strict; then
        warn "$ioc: no PVs to check (${known_issues[$ioc]})"
        continue
    fi
    pod="${ioc}-0"
    read -r -a pvs <<<"${ioc_pvs[$ioc]:-${ioc^^}:UPTIME}"
    for pv in "${pvs[@]}"; do
        checked_any=true
        run_with_retry "direct CA  $ioc $pv" -- \
            kubectl exec -n "$namespace" "$pod" -- caget -w 5 "$pv" || true
        run_with_retry "direct PVA $ioc $pv" -- \
            kubectl exec -n "$namespace" "$pod" -- pvxget -w 5 -r value "$pv" || true
        run_with_retry "gateway CA  $ioc $pv" -- \
            kubectl exec -n "$namespace" "$check_pod" -c "$check_container" -- \
            python3 -c "$ca_get_py" "$pv" || true
        run_with_retry "gateway PVA $ioc $pv" -- \
            kubectl exec -n "$namespace" "$check_pod" -c "$check_container" -- \
            python3 -c "$pva_get_py" "$pv" || true
    done
done <<<"$iocs"
$checked_any || die "no IOC had any PV to check (all excluded?)"

# ---------------------------------------------------------------------------
# 3. blueapi healthz, through its oauth2-proxy

step "3/4: blueapi healthz, through its oauth2-proxy"
healthz_py='
import urllib.request
r = urllib.request.urlopen("http://p47-blueapi-oauth2/healthz", timeout=5)
print(r.status, r.read().decode())
'
run_with_retry "blueapi healthz" -- \
    kubectl exec -n "$namespace" "$check_pod" -c "$check_container" -- \
    python3 -c "$healthz_py" || true

# ---------------------------------------------------------------------------
# 4. OPIs served over HTTP

step "4/4: OPIs served over HTTP"
opis_py='
import urllib.request
r = urllib.request.urlopen("http://p47-epics-opis/", timeout=5)
body = r.read(200).decode(errors="replace")
print(r.status, body.splitlines()[0] if body else "")
'
run_with_retry "p47-epics-opis" -- \
    kubectl exec -n "$namespace" "$check_pod" -c "$check_container" -- \
    python3 -c "$opis_py" || true

# ---------------------------------------------------------------------------
# 5. optional: device-code login and a small plan (needs a person)

step "5/5: optional device-code login and test plan"
cat <<EOF
This step logs in to the real DLS Keycloak (identity.diamond.ac.uk) with a
one-time device code, using blueapi's own CLI - not a script reimplementing
OAuth. A person must complete the login in a browser; this script never
attempts it and never touches auth config.

  blueapi -c <config> login
  blueapi -c <config> controller run $login_plan '$login_params'

The config points at p47's real oidc settings (mirrors the worker config in
services/p47-blueapi/values.yaml:135-139):

  oidc:
    well_known_url: "https://identity.diamond.ac.uk/realms/dls/.well-known/openid-configuration"
    client_id: "blueapiCli"
    client_audience: "account"
  api:
    url: "$blueapi_url"

It needs the blueapi CLI, DLS network access to identity.diamond.ac.uk and
$blueapi_url, and a browser to complete the device code. The default plan
targets a simulated detector; check its device name first with the blueapi
CLI (this device name is not verified against a live login) and override it
with --login-plan/--login-params if it differs.
EOF

if [[ -z $login ]]; then
    if [[ -t 0 ]]; then
        read -r -p "Run it now? [y/N] " answer
        [[ $answer =~ ^[Yy] ]] && login=yes || login=no
    else
        log "non-interactive, so not asking. Skipping (use --login to run it)"
        login=no
    fi
fi

if [[ $login == no ]]; then
    log "skipped"
else
    if ! command -v blueapi >/dev/null; then
        warn "blueapi CLI not found on PATH; install it and re-run with --login"
    else
        config=$(mktemp --suffix .yaml)
        cat >"$config" <<EOF
oidc:
  well_known_url: "https://identity.diamond.ac.uk/realms/dls/.well-known/openid-configuration"
  client_id: "blueapiCli"
  client_audience: "account"
api:
  url: "$blueapi_url"
EOF
        log "logging in (a browser prompt/device code follows; complete it to continue)"
        if blueapi -c "$config" login; then
            log "logged in. Submitting plan '$login_plan' with params: $login_params"
            if blueapi -c "$config" controller run "$login_plan" "$login_params"; then
                log "plan submitted and completed"
            else
                warn "plan '$login_plan' did not complete; this does not fail the smoke test"
            fi
        else
            warn "login did not complete; this does not fail the smoke test"
        fi
        rm -f "$config"
    fi
fi

# ---------------------------------------------------------------------------

echo
if ((failures)); then
    log "$failures check(s) failed, $warnings warning(s). See $troubleshoot_url"
    exit 1
fi
log "all required checks passed ($warnings warning(s))"
