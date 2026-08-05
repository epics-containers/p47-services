# bl47p-ea-simdet

Three simulated area detectors deployed from this one folder by the
[ioc-group](https://github.com/epics-containers/ec-helm-charts/tree/main/Charts/ioc-group)
chart:

| IOC                | PV prefix           | image size |
| ------------------ | ------------------- | ---------- |
| bl47p-ea-simdet-01 | BL47P-EA-SIMDET-01: | 1024x1024  |
| bl47p-ea-simdet-02 | BL47P-EA-SIMDET-02: | 640x480    |
| bl47p-ea-simdet-03 | BL47P-EA-SIMDET-03: | 256x256    |

`ioc-group` renders the `ioc-instance` library once per entry in `iocs`. Each
entry's `NAME` is appended to the release name, so every IOC gets its own
StatefulSet, ConfigMap and PVC. The other keys in an entry become container
environment variables for that IOC alone, which is how the single shared
`config/ioc.yaml` gives each detector a different image size - it reads them
back with `{{ _global.get_env('WIDTH') }}`.

To add a fourth detector, add another entry to `iocs` in `values.yaml`. The
config folder does not change.

## Local checkout of ec-helm-charts required (for now)

`ioc-group` has not been released to `oci://ghcr.io/epics-containers/charts`
yet, so `.helm-shared/GroupChart.yaml` points at a local checkout of
`ec-helm-charts` next to this repo. Two consequences until it is released:

1. Build `ioc-group`'s own dependencies once before deploying, otherwise the
   packaged `ioc-group` has no `ioc-instance` inside it and `helm template`
   fails with `no template "ioc-instance" associated with template "gotpl"`:

   ```bash
   helm dependency update ../ec-helm-charts/Charts/ioc-group
   ```

2. This instance is listed in `.ci_skip_checks`, because CI runs helm in a
   container that cannot see `../ec-helm-charts`.

When `ioc-group` is released, switch `.helm-shared/GroupChart.yaml` to the
commented out `oci://` lines and remove `bl47p-ea-simdet` from
`.ci_skip_checks`.
