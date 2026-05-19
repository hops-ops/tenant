# tenant

`Tenant` is the platform's business-object XRD. One `Tenant` per customer agreement / business relationship. Scaffolds the per-Tenant identity slice (Zitadel `Org` + default `Project` + default `Role`s), the analytics slice (OpenPanel `Organization` + default `Project`), and optional K8s isolation (Capsule `Tenant` CR) in a per-Tenant namespace.

Sits one layer above the stacks. [tenant-stack](https://github.com/hops-ops/tenant-stack) installs Capsule cluster-wide; [auth-stack](https://github.com/hops-ops/auth-stack) installs Zitadel; [analytics-stack](https://github.com/hops-ops/analytics-stack) installs OpenPanel. This `Tenant` XRD consumes those primitives (plus the Zitadel + OpenPanel provider MRs) to scaffold a real tenant in one apply.

See [[specs/tenant-xrd]] and [[specs/identity-architecture]] for the design.

## Quick Start

Full Tenant with identity + analytics + K8s isolation:

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
    zitadel: {}                        # defaults: orgName = metadata.name; tenant-admin + tenant-member roles
  analytics:
    openpanel:
      enabled: true                    # composes OpenPanel Org + default Project
  capsule:
    enabled: true
    userGroups: [tenant-admin]
```

## What gets composed

| Resource | Provider | When |
|---|---|---|
| `Namespace` (per-Tenant) | provider-kubernetes Object | always |
| Zitadel `Org` | provider-upjet-zitadel | always |
| Zitadel default `Project` | provider-upjet-zitadel | unless `identity.zitadel.defaultProject.skip: true` |
| Zitadel default `Role`s | provider-upjet-zitadel | one per `identity.zitadel.defaultProject.roles[]`; defaults to `tenant-admin` + `tenant-member` |
| OpenPanel `Organization` | provider-openpanel | when `analytics.openpanel.enabled: true` |
| OpenPanel default `Project` | provider-openpanel | when `analytics.openpanel.enabled: true` and `analytics.openpanel.defaultProject.skip: false` |
| Capsule `Tenant` CR | provider-kubernetes Object | when `capsule.enabled: true` |

Multi-iteration convergence (per [[feedback_crossplane_composition_gates]]):
1. **Iter 1**: Namespace + Zitadel Org + OpenPanel Org + (optional) Capsule Tenant
2. **Iter 2**: once Zitadel Org observed → Zitadel default Project + Roles emit; once OpenPanel Org observed → OpenPanel default Project emits

Zitadel `Role` MRs use `projectIdRef` to cross-resource reference the composed Project — Crossplane resolves the Zitadel projectId at reconcile time. OpenPanel Project's `organizationId` is a plain string with no `*Ref` field on the provider's MR, so we gate emission on observed Org id.

## Adoption (existing external resources)

To take over an existing Zitadel or OpenPanel Org, set its id in the spec — the composition propagates it as the composed MR's `crossplane.io/external-name` annotation. Pair with `managementPolicies` excluding `Create`:

```yaml
spec:
  identity:
    zitadel:
      orgId: "373268222482392664"      # existing Zitadel Org UUID
      defaultProject:
        skip: true                      # existing Org has its own Projects; manage via raw MRs
  analytics:
    openpanel:
      enabled: true
      orgId: "<existing-openpanel-org-uuid>"
  managementPolicies: ["Observe", "Update", "LateInitialize"]
```

**Alternative**: apply the XR without `orgId`, then `kubectl annotate org <name>-org crossplane.io/external-name=<id>` afterward. Same end state. The spec-field path is more declarative; the kubectl-annotate path matches the "create then adopt" flow some operators prefer.

**OpenPanel adoption notes**: per [[reference_openpanel_organization_upsert_semantics]], OpenPanel's TF provider Create is find-or-create — adoption via `crossplane.io/external-name` is the safe path. Always set `analytics.openpanel.orgId` when adopting (or `kubectl annotate` immediately after apply).

## What's NOT composed

- **Additional Zitadel Projects/Roles beyond the default Project**: operators apply raw `Project` / `Role` MRs (`project.zitadel.m.crossplane.io`) in the per-Tenant namespace.
- **Additional OpenPanel Projects/Clients**: operators apply raw OpenPanel MRs.
- **HumanUsers, MachineUsers, Grants, IDPs, OrganizationSsoConfig**: separate XRDs in the auth-stack repo (still TO WRITE). When they land, they're applied as standalone XRs in the per-Tenant namespace.
- **Foundation refs**: `accounts.*.foundationRef` is echoed in status but NOT composed. Foundation XR lifecycle is owned by `aws-foundation` (and equivalents).

## ProviderConfig conventions

Defaults derive from `spec.clusterName`:

- `providerConfigRefs.kubernetes` → `<clusterName>` (e.g., `pat-local`)
- `providerConfigRefs.zitadel` → `<clusterName>-zitadel` (e.g., `pat-local-zitadel`)
- `providerConfigRefs.openpanel` → `<clusterName>-openpanel` (e.g., `pat-local-openpanel`)

Override explicitly when the convention doesn't fit (e.g., bring-your-own Zitadel/OpenPanel pointing at a tenant-owned instance).

**Namespace constraint**: per [[reference_v2_providerconfig_same_namespace_lookup]], Crossplane v2 namespaced MRs can only resolve ProviderConfigs in their own namespace. Either use `ClusterProviderConfig` variants OR ensure the PCs live in the same namespace as the per-Tenant resources.

## Examples

- `examples/tenants/standard.yaml` — full Tenant with identity + analytics + capsule + Foundation echo
- `examples/tenants/adopt.yaml` — adopts the existing pat-local `tenant-platform` Zitadel Org
- `examples/tenants/minimal.yaml` — Zitadel-only personal-brand Tenant (`pat-brand`); no analytics, no capsule

## References

- Spec: `[[specs/tenant-xrd]]`
- Umbrella: `[[specs/identity-architecture]]`
- Sibling stacks: `[[specs/tenant-stack]]`, `[[specs/auth-stack-zitadel]]`, `[[specs/analytics-stack-openpanel]]`
- Memories: `feedback_crossplane_composition_gates`, `reference_openpanel_organization_upsert_semantics`, `reference_v2_providerconfig_same_namespace_lookup`
