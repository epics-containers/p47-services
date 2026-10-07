# p47-nightly-smoke

A nightly smoke test of the `p47-blueapi` service. It runs as a Kubernetes
CronJob in the `p47-beamline` namespace on `pollux` and uses the
`ghcr.io/epics-containers/ec-nightly:0.1.0-beta.5` image (the first image with
the `scan` check; not yet published at the time of writing). It is built from
the `scheduled-jobs` chart (5.15.0-beta.1).

## What it does

Every night at 01:00 (Europe/London) the job obtains a token from Keycloak
(client credentials), then makes read-only requests to blueapi and runs one
plan on it, at
`http://p47-blueapi.p47-beamline.svc.cluster.local:80`. blueapi validates the
bearer token itself, so the job goes straight to the service and not via
oauth2-proxy.

The checks are `token`, `health`, `environment`, `plans`, `devices`,
`worker` and `scan`. `EXPECTED_PLANS` and `EXPECTED_DEVICES` are not set, so the `plans`
and `devices` checks only assert that blueapi lists at least one of each. The
blueapi image bakes in `dodal` and `htss_rig_bluesky` and this repo does not pin
their versions, so there are no names we can rely on. To assert specific ones,
add them as comma-separated env vars in `values.yaml` once the deployed
versions are known.

### The scan

The `scan` check submits a plan to blueapi's task API, starts it on the worker,
polls it until it completes and fails the job if blueapi rejects the plan or
its parameters, the plan ends with an error, or it takes longer than
`SCAN_TIMEOUT` (300 s; the job then aborts its own task). It is set by these
env vars in `values.yaml`:

| Variable | Value | Meaning |
|---|---|---|
| `SCAN_PLAN` | `num_rscan` | dodal's relative N-point scan |
| `SCAN_PARAMS` | `{"detectors": ["det"], "params": [["sample_stage.x", [-0.5, 0.5]]], "num": 3}` | move the training rig stage x from -0.5 to +0.5 relative to where it is, in 3 points, reading the camera at each; the stage returns to its start afterwards |
| `SCAN_INSTRUMENT_SESSION` | `REPLACE-WITH-P47-SESSION` | **must be replaced** with a real p47 instrument session the client may use; blueapi requires one on every task |
| `SCAN_TIMEOUT` | `300` | seconds |

`det` and `sample_stage` are the device names of
`dodal.beamlines.training_rig` with `BEAMLINE=p47`: the Aravis camera of
`bl47p-ea-dcam-01` (`BL47P-EA-DET-01`) and the stage of `bl47p-mo-ioc-01`
(`BL47P-MO-MAP-01:STAGE`). The scan moves that stage. To run a different plan,
change these values; `blueapi controller plans` and `blueapi controller
devices` list what the deployed blueapi offers. Set `SCAN_PLAN` to an empty
string to skip the scan.

The CronJob is named `p47-nightly-smoke-blueapi`
(`<service>-<job>`), a run is limited to 30 minutes and is never retried.

## Secret

The client must be allowed to submit and start tasks, not just read from
blueapi, for the `scan` check to pass; a 401 or 403 from the task API is
reported as "not authorised".

The job reads `CLIENT_ID` and `CLIENT_SECRET` from the Secret
`p47-blueapi-test-runner` (keys `client-id` and `client-secret`) in
`p47-beamline`. That Secret is not part of this service and must exist in the
namespace before the job can authenticate. Without it the pod fails with
`CreateContainerConfigError`. The pod does not mount a ServiceAccount token.

## Run it manually

```bash
module load pollux   # or otherwise select the pollux cluster
kubectl -n p47-beamline create job --from=cronjob/p47-nightly-smoke-blueapi smoke-manual-1
kubectl -n p47-beamline logs -f job/smoke-manual-1
```

Clean up afterwards (finished jobs are otherwise kept until deleted):

```bash
kubectl -n p47-beamline delete job smoke-manual-1
```

Alternatively, in the Argo CD UI open the `p47-nightly-smoke` app, click the
`p47-nightly-smoke-blueapi` CronJob and choose Create Job from the CronJob
menu. Delete the job there when done.

## Reading the results

- The pod log shows one PASS or FAIL line per check. A failed check includes
  the reason, for example "not authorised". Tokens and secrets are never logged.
- Exit code 0 means every check passed, 1 means a check failed (or the report
  could not be written), 2 means a configuration error such as a missing
  `BLUEAPI_URL`. `kubectl -n p47-beamline get jobs` shows Complete or Failed.
- `report.json` and `report.xml` (JUnit) are written to
  `/reports/<UTC timestamp>/blueapi/` in the pod. `/reports` is an `emptyDir`,
  so the files only live as long as the pod. To read them, rely on the log, or
  run `kubectl exec` while a pod is still running.
- The last 7 successful and 7 failed jobs are kept, so
  `kubectl -n p47-beamline get jobs,pods -l app=p47-nightly-smoke` lists recent
  runs.
