# Helm Values Propagation: Parent, Child, and Grandchild Charts

A summary of how values flow between Helm chart dependencies, including limitations when working with nested (grandchild) charts.

## import-values: Pulling Values Up

The `import-values` directive in `Chart.yaml` lets a parent chart import default values from a child:

```yaml
dependencies:
  - name: ioc-instance
    version: 5.1.0
    repository: "oci://ghcr.io/epics-containers/charts"
    import-values:
      - child: ioc-instance
        parent: ioc-instance
```

This works for both **library** and **application** charts—Helm treats them identically for value imports.

### Two approaches for import-values

1. **Using `exports`** (child explicitly defines what to export):
   ```yaml
   # Child's values.yaml
   exports:
     ioc-instance:
       someKey: someValue
   ```

2. **Direct path import** (grab any value path from child):
   ```yaml
   import-values:
     - child: defaults.someSection
       parent: mySection
   ```

## Setting Child Values from Parent

The parent can set values in any dependency by nesting under the child's name:

```yaml
# Parent's values.yaml
ioc-instance:
  image: myregistry/myimage:v1.0
  replicas: 2
```

Or use an `alias` in `Chart.yaml` to change the key name:

```yaml
# Chart.yaml
dependencies:
  - name: ioc-instance
    alias: myioc
    ...
```

Then in values.yaml use `myioc:` instead.

## The Grandchild Problem

**Scenario**: You have a parent chart, with a child chart that depends on a 3rd-party grandchild chart. You want to expose grandchild settings at the root level without exposing the full nesting path.

### Why this is hard

- `import-values` only affects **default values at chart build time**
- It does NOT remap where **user-supplied values** flow at install time
- Helm's value flow is strictly hierarchical: `parent.child.grandchild.setting`
- There's no native "value transformation" layer

### Solutions

| Approach | Pros | Cons |
|----------|------|------|
| **`global:` values** | Automatically cascade to all depths; no config needed | Grandchild must read from `global`; namespace pollution |
| **Child remaps values** | Clean interface; full control | Requires child cooperation; manual sync |
| **External tooling** (Helmfile, Kustomize, ArgoCD) | Powerful transformation | Additional tooling complexity |
| **Vendor/fork grandchild** | Full control | Lose automatic updates |

### Using global values

```yaml
# Parent's values.yaml
global:
  mySharedSetting: value
```

Accessible in any grandchild template as `.Values.global.mySharedSetting`.

### Child remapping (if you control the child)

Define a clean interface in the child's `values.yaml` and pass values to grandchild:

```yaml
# Child's values.yaml

# Clean interface for users
myCleanName: "default"

# 3rd party grandchild chart
postgres:
  auth:
    password: "default"
```

**Limitation**: No automatic sync between `myCleanName` and `postgres.auth.password`—document the preferred interface.

## Value Override Hierarchy

Values cascade in this order (later wins):

1. Child chart's default `values.yaml`
2. Parent chart's `values.yaml` (under child's key)
3. Values files passed via `helm install -f`
4. Values passed via `helm install --set`

## Conclusion

Helm's value propagation is powerful for two-level hierarchies but has real limitations for grandchild charts:

- **You CAN**: Set child values from parent, import child defaults to parent
- **You CANNOT**: Transparently remap grandchild value paths without child cooperation or external tooling

This is a recognized pain point in Helm—it's one reason tools like Helmfile exist for more complex deployments.

## References

- [Helm Subcharts and Global Values](https://helm.sh/docs/chart_template_guide/subcharts_and_globals/)
- [Helm Dependency Management](https://helm.sh/docs/helm/helm_dependency/)
