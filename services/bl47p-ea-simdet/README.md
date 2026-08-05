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

## Chart version

`.helm-shared/GroupChart.yaml` pins `ioc-group` 5.7.0-beta.1 from
`oci://ghcr.io/epics-containers/charts`. That is a **prerelease**, cut from the
`repeating-ioc` branch of `ec-helm-charts` so that this group can be tested in
argocd - bump it to a stable version once `ioc-group` is merged to main.

The packaged `ioc-group` vendors the `ioc-instance` library it was built
against, so unlike the single IOC services this one does not depend on
`ioc-instance` directly and does not follow the version in
`.helm-shared/Chart.yaml`.
