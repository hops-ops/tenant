### What's changed in v0.1.0

* feat: initial Tenant XRD (by @patrickleet)

  Platform business-object kind. One Tenant per customer agreement /
  business relationship. Scaffolds the per-Tenant identity slice
  (Zitadel Org + default Project + default Roles) and optional K8s
  isolation (Capsule Tenant CR) in a per-Tenant namespace.

  v1 scope (per [[specs/tenant-xrd]] and the live design discussion):
  - Composes Namespace + Zitadel Org + default Project + default Roles
    + (when capsule.enabled) Capsule Tenant CR
  - identity.zitadel.mode supports "create" and "adopt"
  - defaultProject.skip: true opts out of the default Project for tenants
    that manage their Projects via raw Zitadel MRs
  - Default roles fall back to tenant-admin + tenant-member when not supplied
  - Foundation refs echoed in status, NOT composed (Foundation lifecycle
    owned externally)
  - Analytics-side (OpenPanel) NOT composed in v1 — operators apply raw
    OpenPanel MRs in the per-Tenant namespace

  Composition uses observed-state gating per
  [[feedback_crossplane_composition_gates]]: Zitadel Project + Roles
  defer emission until the Org is observed (orgId populated). Standard
  Crossplane multi-iteration convergence — first iteration creates
  Org + Namespace + Capsule Tenant; subsequent iterations add Project +
  Roles once Org status is read back.

  Resources composed:
  - Namespace (provider-kubernetes Object)
  - Zitadel Org (org.zitadel.m.crossplane.io)
  - Zitadel default Project (project.zitadel.m.crossplane.io)
  - Zitadel default Roles (one per spec.identity.zitadel.defaultProject.roles[]
    entry; uses projectIdRef cross-resource ref to the composed Project)
  - Capsule Tenant CR (provider-kubernetes Object; capsule.clastix.io/v1beta2)

  Three examples (standard / adopt / minimal) all render via
  up composition render. Standard iter-2 simulation (observed Org with
  populated orgId) verified composes the default Project + Roles correctly.

  Multi-API Makefile mirrored from psql-stack — single XRD today, but
  ready when analytics-side composition or other business kinds land.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>

* :  (by @patrickleet)

* fix: gate defaultProject status emission on defaultProject.skip (by @patrickleet)

  When spec.identity.zitadel.defaultProject.skip: true (e.g., adopting an
  existing Zitadel Org whose Projects are already in place), the
  composition correctly skips emitting the Project + Role MRs but the
  status was still emitting an empty defaultProject block with the fallback
  role list (tenant-admin/tenant-member) — both confusing and inaccurate.

  Two changes:
  - 010-state-status: skip the per-role observed-state lookup when
    defaultProject.skip is true (avoids populating rolesStatus dict with
    empty roleIds)
  - 999-status: gate the entire identity.zitadel.defaultProject block on
    not-skip; when skipped, only mode + orgId remain under identity.zitadel

  Verified live on colima: applying examples/tenants/adopt.yaml (which uses
  defaultProject.skip: true) now shows clean status without the spurious
  defaultProject block.

  Found during the colima live test of the adopt-mode path against the
  existing tenant-platform Zitadel Org (id 373268222482392664).

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>

* refactor: drop create/adopt mode; add analytics-side composition (by @patrickleet)

  Two changes per the live-test design feedback:

  1. Schema simplification — drop the identity.zitadel.{mode, create, adopt}
     discriminator. Flat schema:

       identity:
         zitadel:
           orgName: ""           # defaults to metadata.name
           orgId:   ""           # optional; if set, propagates as external-name (adopt)
           defaultProject:
             skip: false
             name: ""
             roles: []

     Adoption is now Crossplane-idiomatic: set spec.identity.zitadel.orgId
     to propagate as the underlying Org MR's crossplane.io/external-name
     annotation, OR apply the XR fresh and `kubectl annotate` the composed
     MR afterward. No more mode-with-sub-blocks ceremony.

  2. Analytics-side composition added — same shape, new fields:

       analytics:
         openpanel:
           enabled: false        # default off
           orgName: ""           # defaults to display.name
           orgId:   ""           # optional adoption
           defaultProject:
             skip: false
             name: ""

     When enabled, the composition emits:
     - OpenPanel Organization MR (organizations.organization.openpanel.m.crossplane.io)
     - OpenPanel default Project MR (gated on observed Org id — multi-iteration
       same as the Zitadel side; OpenPanel Project's organizationId is a
       plain string, no *Ref cross-resource pattern)

     Per reference_openpanel_organization_upsert_semantics, OpenPanel's TF
     provider Create is find-or-create; spec.analytics.openpanel.orgId
     propagates external-name to defend against the rename-and-cascade
     pitfall when adopting.

  upbound.yaml gains ghcr.io/hops-ops/provider-openpanel >=v1.0.1 dependency.

  Verified locally:
  - make render:all passes for all 3 examples
  - standard iter-1 emits Namespace + Capsule + Zitadel Org + OpenPanel Org;
    Project/Roles + OpenPanel Project correctly gated
  - standard iter-2 (observed-resources fixture with both Org IDs populated)
    emits Zitadel default Project + 2 Roles + OpenPanel default Project
  - up test run tests/test-tenant: 5/5 pass, including new analytics-adopt
    test case

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>

* docs: neutralize the namespace-constraint section in README (by @patrickleet)

  I had written 'production target is ClusterProviderConfig variants' which
  was me declaring an unrequested solution as authoritative. Rewriting to
  just describe the constraint and note that the resolution path is an
  operational choice — not the XRD's call to make.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>

* :  (by @patrickleet)


