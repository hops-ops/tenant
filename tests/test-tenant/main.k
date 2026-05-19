import models.ai.com.ops.hops.v1alpha1 as hopsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# ==============================================================================
# Unit tests for Tenant XRD
#
# Verify the composition's first-iteration emission and key conditional
# behaviors. Multi-iteration deferred-compose (Project/Roles after orgId
# observed, OpenPanel Project after opOrgId observed) is verified via
# `up composition render --observed-resources` against
# tests/test-tenant/observed/standard-iter2.yaml.
# ==============================================================================

_items = [
    # ==========================================================================
    # Test 1: standard create — Namespace + Capsule Tenant + Zitadel Org +
    # OpenPanel Org compose on first iteration (analytics enabled).
    # Zitadel Project/Roles + OpenPanel Project gated.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "create-mode-iter1-with-analytics"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "ops-com-ai", namespace = "default"}
                spec = {
                    clusterName = "pat-local"
                    type = "business"
                    display = {name = "ops.com.ai", primaryDomain = "ops.com.ai"}
                    identity = {zitadel = {}}
                    analytics = {openpanel = {enabled = True}}
                    capsule = {enabled = True, userGroups = ["tenant-admin"]}
                }
            }
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "ops-com-ai-namespace"
                    spec.forProvider.manifest.kind = "Namespace"
                }
                {
                    apiVersion = "org.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Org"
                    metadata.name = "ops-com-ai-org"
                    spec = {
                        forProvider.name = "ops-com-ai"
                        providerConfigRef = {name = "pat-local-zitadel", kind = "ProviderConfig"}
                    }
                }
                {
                    apiVersion = "organization.openpanel.m.crossplane.io/v1alpha1"
                    kind = "Organization"
                    metadata.name = "ops-com-ai-openpanel-org"
                    spec = {
                        forProvider.name = "ops.com.ai"
                        providerConfigRef = {name = "pat-local-openpanel", kind = "ProviderConfig"}
                    }
                }
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "ops-com-ai-capsule-tenant"
                }
            ]
        }
    },

    # ==========================================================================
    # Test 2: adoption via spec.identity.zitadel.orgId — propagates as
    # external-name annotation on the Org MR.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "adopt-org-via-orgid"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "ops-com-ai", namespace = "default"}
                spec = {
                    clusterName = "pat-local"
                    display = {name = "ops.com.ai", primaryDomain = "ops.com.ai"}
                    identity = {
                        zitadel = {
                            orgId = "373268222482392664"
                            defaultProject = {skip = True}
                        }
                    }
                    capsule = {enabled = True, userGroups = ["tenant-admin"]}
                    managementPolicies = ["Observe", "Update", "LateInitialize"]
                }
            }
            assertResources = [
                {
                    apiVersion = "org.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Org"
                    metadata = {
                        name = "ops-com-ai-org"
                        annotations = {"crossplane.io/external-name" = "373268222482392664"}
                    }
                    spec = {
                        forProvider.name = "ops-com-ai"
                        managementPolicies = ["Observe", "Update", "LateInitialize"]
                    }
                }
            ]
        }
    },

    # ==========================================================================
    # Test 3: minimal — no capsule, no analytics. Only Namespace + Zitadel Org.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "minimal-zitadel-only"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "pat-brand", namespace = "default"}
                spec = {
                    clusterName = "pat-local"
                    type = "individual"
                    display = {
                        name = "Pat Scott"
                        primaryDomain = "patscott.io"
                        aliasDomains = ["patrickleescott.com"]
                    }
                    identity = {zitadel = {}}
                    capsule = {enabled = False}
                }
            }
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "pat-brand-namespace"
                }
                {
                    apiVersion = "org.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Org"
                    metadata.name = "pat-brand-org"
                }
            ]
        }
    },

    # ==========================================================================
    # Test 4: analytics adoption via spec.analytics.openpanel.orgId —
    # OpenPanel Org gets external-name annotation.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "adopt-openpanel-org-via-orgid"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "ops-com-ai", namespace = "default"}
                spec = {
                    clusterName = "pat-local"
                    display = {name = "ops.com.ai", primaryDomain = "ops.com.ai"}
                    identity = {zitadel = {}}
                    analytics = {
                        openpanel = {
                            enabled = True
                            orgId = "openpanel-existing-org-uuid"
                            defaultProject = {skip = True}
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "organization.openpanel.m.crossplane.io/v1alpha1"
                    kind = "Organization"
                    metadata = {
                        name = "ops-com-ai-openpanel-org"
                        annotations = {"crossplane.io/external-name" = "openpanel-existing-org-uuid"}
                    }
                }
            ]
        }
    },

    # ==========================================================================
    # Test 5: custom orgName + custom default project name + custom roles.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "custom-org-project-roles"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "thrivendale", namespace = "default"}
                spec = {
                    clusterName = "pat-local"
                    display = {name = "Thrivendale", primaryDomain = "thrivendale.com"}
                    identity = {
                        zitadel = {
                            orgName = "thrivendale-prod"
                            defaultProject = {
                                name = "thrivendale-app"
                                roles = [
                                    {key = "admin", displayName = "Admin", group = "admin"}
                                    {key = "member", displayName = "Member"}
                                ]
                            }
                        }
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "org.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Org"
                    metadata.name = "thrivendale-org"
                    spec.forProvider.name = "thrivendale-prod"
                }
            ]
        }
    },
]

items = _items
