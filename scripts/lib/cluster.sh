# shellcheck shell=bash
# shellcheck disable=SC2034  # the bl_* globals are used by the callers
#
# Find a beamline's Services with kubectl. Source this from a bash script,
# it does nothing on its own. Adapted, structure and behaviour unchanged,
# from epics-containers/t11-deployment scripts/lib/cluster.sh.
#
# Set before calling:
#   bl_prog         prefix for error messages, e.g. smoke-test.sh
#   bl_env_hint     the overrides named when kubectl is missing,
#                   e.g. "OPIS and GATEWAY" (default: GATEWAY); set it
#                   empty when the caller has no overrides
#
# The functions never exit. On failure they print "<bl_prog>: message" to
# stderr and return 1, so a caller can run e.g. `bl_check_namespace ns || exit 1`.
# Progress messages also go to stderr, so stdout holds only the results.
# Results are returned in variables, not on stdout, so that checks already
# done are remembered and not repeated:
#   bl_check_namespace NAMESPACE sets bl_context to the kubectl context
#   bl_gateway_host NAMESPACE    sets bl_gateway to the gateway host

# the "namespace/service" pairs that bl_check_cluster has already checked
_bl_checked=()
# the namespace that bl_check_namespace has already reached
_bl_reached=""

# print a progress message with the calling script's prefix
bl_note() {
    echo "${bl_prog:-${0##*/}}: $*" >&2
}

# print a message with the calling script's prefix, and fail
bl_error() {
    bl_note "$@"
    return 1
}

# fail, with a clear message, when kubectl cannot read the Services
#   bl_check_cluster NAMESPACE SERVICE...
bl_check_cluster() {
    local namespace=$1 service found todo=()
    shift
    for service in "$@"; do
        [[ " ${_bl_checked[*]} " == *" $namespace/$service "* ]] || todo+=("$service")
    done
    ((${#todo[@]})) || return 0

    bl_check_namespace "$namespace" || return

    for service in "${todo[@]}"; do
        # Empty output means NotFound; authentication, transport and RBAC
        # errors remain visible and must not be reported as a missing Service.
        found=$(kubectl get service "$service" -n "$namespace" --ignore-not-found -o name) || {
            bl_error "cannot read Service '$service' in namespace '$namespace' (context '$bl_context'); kubectl's error is above"
            return 1
        }
        [[ -n $found ]] ||
            bl_error "no Service '$service' in namespace '$namespace' (context '$bl_context'). Select the workload cluster where the beamline Pods run, which may differ from the Argo CD cluster." || return
        _bl_checked+=("$namespace/$service")
    done
}

# fail, with a clear message, when kubectl cannot read Services in the
# namespace. Sets bl_context to the kubectl context.
#   bl_check_namespace NAMESPACE
bl_check_namespace() {
    local namespace=$1
    [[ $_bl_reached != "$namespace" ]] || return 0

    local hint=${bl_env_hint-GATEWAY}
    command -v kubectl >/dev/null ||
        bl_error "no kubectl. Point KUBECONFIG at the workload cluster${hint:+, or set $hint}." || return

    bl_context=$(kubectl config current-context 2>/dev/null) ||
        bl_error "kubectl has no current context. Set KUBECONFIG to a valid kubeconfig." || return

    # can-i prints yes or no when the cluster answers, and an error when not.
    # Leave stderr on the terminal: when the token has expired, kubectl's
    # login plugin prints its browser prompt there and waits for the login
    bl_note "checking that context '$bl_context' can reach namespace '$namespace'. If your token has expired, kubectl asks you to log in"
    # A five-second request deadline also interrupts interactive device login.
    # Use kubectl's default timeout so the user can complete authentication.
    local out status=0
    out=$(kubectl auth can-i get services -n "$namespace") || status=$?
    if grep -qx no <<<"$out"; then
        bl_error "context '$bl_context' cannot read Services in namespace '$namespace'. Check the namespace name and your access."
        return
    elif ((status != 0)) || ! grep -qx yes <<<"$out"; then
        bl_error "cannot reach the cluster for context '$bl_context'. Check the VPN or tunnel, and log in again if your token has expired. kubectl's error is above."
        return
    fi
    _bl_reached=$namespace
}

# print a field of a Service, selected by a jsonpath
#   bl_service_field NAMESPACE SERVICE JSONPATH
bl_service_field() {
    kubectl get service "$2" -n "$1" -o jsonpath="$3"
}

# set bl_gateway to the gateway host, from GATEWAY or the external IP of
# the p47-epics-gateways Service
#   bl_gateway_host NAMESPACE
bl_gateway_host() {
    if [[ -n ${GATEWAY:-} ]]; then
        bl_gateway=$GATEWAY
        return 0
    fi
    bl_check_cluster "$1" p47-epics-gateways || return
    bl_note "looking up the gateway's external IP"
    bl_gateway=$(bl_service_field "$1" p47-epics-gateways '{.status.loadBalancer.ingress[0].ip}') || return
    [[ -n $bl_gateway ]] ||
        bl_error "p47-epics-gateways in namespace '$1' has no external IP yet"
}
