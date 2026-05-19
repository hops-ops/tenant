# tenant

`Tenant` is the platform's business-object XRD. One `Tenant` per customer agreement / business relationship. Each `Tenant` scaffolds the per-Tenant identity slice (Zitadel `Org` + default `Project` + default `Role`s) and optional K8s isolation (Capsule `Tenant` CR) in a per-Tenant namespace.

Sits one layer above the stacks. [tenant-stack](https://github.com/hops-ops/tenant-stack) installs Capsule cluster-wide; this `Tenant` XRD consumes that primitive (plus the Zitadel `Org`/`Project`/`Role` MRs from `provider-upjet-zitadel`) to scaffold a real tenant.

See [[specs/tenant-xrd]] and [[specs/identity-architecture]] for the design.

## Quick Start

Standard create mode — fresh Zitadel Org + default Project + default Roles + per-Tenant Namespace + Capsule Tenant:

```yaml
apiVersion: hops.ops.com.ai/v1alpha1
kind: Tenant
metadata:
  name: ops-com-ai
  namespace: tenants
spec:
  clusterName: pat-local
  type: business
  display:
    name: "ops.com.ai"
    primaryDomain: ops.com.ai
  identity:
    zitadel:
      mode: create
  capsule:
    enabled: true
    userGroups: [tenant-admin]
  accounts:
    aws:
      foundationRef:
        apiVersion: aws.hops.ops.com.ai/v1alpha1
        kind: Foundation
        name: ops-com-ai-aws
        namespace: foundations
  billing:
    tag: ops-com-ai
    budgets: { monthly: 1000, alertThresholdPercent: 80 }
```

## What gets composed

Per Tenant XR, the composition emits:

| Resource | Provider | When |
|---|---|---|
| `Namespace` (per-Tenant) | provider-kubernetes Object | always |
| Zitadel `Org` | provider-upjet-zitadel | always |
| Zitadel default `Project` | provider-upjet-zitadel | unless `identity.zitadel.defaultProject.skip: true` |
| Zitadel default `Role`s | provider-upjet-zitadel | one per `identity.zitadel.defaultProject.roles[]` entry; defaults to `tenant-admin` + `tenant-member` |
| Capsule `Tenant` CR | provider-kubernetes Object | when `capsule.enabled: true` |

Multi-iteration convergence: the Zitadel Project + Roles are gated on the Org being observed (its server-assigned `atProvider.id` populated). First iteration creates Org + Namespace + Capsule; subsequent iterations add Project + Roles. This matches the [[feedback_crossplane_composition_gates]] convention.

## Modes

| Mode | When | Mechanism |
|---|---|---|
| `create` | New Tenant | Fresh Zitadel Org composed; server-assigned ID |
| `adopt` | Migration from existing pat-local state | `identity.zitadel.adopt.orgId` propagated as `crossplane.io/external-name` on the Org MR |

External mode (tenant-owned Zitadel) is deferred. When it lands, operators will set `identity.zitadel.mode: external` and supply their own ProviderConfig.

## What's NOT composed

Several things the umbrella spec contemplated are deliberately left to follow-up commits or to operators applying raw MRs:

- **Analytics-side** (OpenPanel Org/Project/Client + OrganizationSsoConfig): operators apply raw OpenPanel MRs in the per-Tenant namespace. v1.x may compose these once we've validated the pattern.
- **Additional Zitadel Projects/Roles** beyond the default Project: operators apply raw `Project` / `Role` MRs (`project.zitadel.m.crossplane.io`) in the per-Tenant namespace.
- **HumanUsers, MachineUsers, Grants, IDPs**: separate XRDs in the auth-stack repo (still TO WRITE at the time of this commit). When they land, they're applied as standalone XRs in the per-Tenant namespace and reference the Tenant via either `tenantRef` or direct `orgId` string.
- **Foundation refs**: `accounts.*.foundationRef` is echoed in status but NOT composed. Foundation XR lifecycle is owned by `aws-foundation` (and equivalents).

## ProviderConfig conventions

Defaults derive from `spec.clusterName`:

- `providerConfigRefs.kubernetes` → `<clusterName>` (e.g., `pat-local`)
- `providerConfigRefs.zitadel` → `<clusterName>-zitadel` (e.g., `pat-local-zitadel`)

Override explicitly when the convention doesn't fit (e.g., bring-your-own Zitadel pointing at a tenant-owned instance).

## Examples

- `examples/tenants/standard.yaml` — full create mode for the `ops-com-ai` Tenant
- `examples/tenants/adopt.yaml` — adopts pat-local's existing `tenant-platform` Org under the `ops-com-ai` Tenant name
- `examples/tenants/minimal.yaml` — multi-domain personal-brand Tenant (`pat-brand`); no Capsule

## References

- Spec: `[[specs/tenant-xrd]]`
- Umbrella: `[[specs/identity-architecture]]`
- Sibling stack (Capsule install): `[[specs/tenant-stack]]`
- Memory: `feedback_crossplane_composition_gates` (the multi-iteration gating convention used here)
