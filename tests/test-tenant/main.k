import models.ai.com.ops.hops.v1alpha1 as hopsv1alpha1
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# ==============================================================================
# Unit tests for Tenant XRD
#
# Verify the composition's first-iteration emission (Namespace + Capsule
# Tenant + Zitadel Org) and the defaultProject.skip toggle. The Project +
# Role MR emission gated on observed orgId is verified separately via
# `up composition render --observed-resources` against
# tests/test-tenant/observed/standard-iter2.yaml.
# ==============================================================================

_items = [
    # ==========================================================================
    # Test 1 (standard create): Namespace + Capsule Tenant + Zitadel Org all
    # compose on first iteration. ProviderConfigRefs derive from clusterName.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "create-mode-iter1-namespace-capsule-org"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "ops-com-ai", namespace = "tenants"}
                spec = {
                    clusterName = "pat-local"
                    type = "business"
                    display = {
                        name = "ops.com.ai"
                        primaryDomain = "ops.com.ai"
                    }
                    identity = {
                        zitadel = {mode = "create"}
                    }
                    capsule = {enabled = True, userGroups = ["tenant-admin"]}
                }
            }
            assertResources = [
                # Namespace (per-Tenant)
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "ops-com-ai-namespace"
                    spec = {
                        forProvider.manifest = {
                            apiVersion = "v1"
                            kind = "Namespace"
                            metadata.name = "ops-com-ai"
                        }
                        providerConfigRef = {name = "pat-local", kind = "ProviderConfig"}
                    }
                }
                # Zitadel Org
                {
                    apiVersion = "org.zitadel.m.crossplane.io/v1alpha1"
                    kind = "Org"
                    metadata.name = "ops-com-ai-org"
                    spec = {
                        forProvider.name = "ops-com-ai"
                        managementPolicies = ["*"]
                        providerConfigRef = {name = "pat-local-zitadel", kind = "ProviderConfig"}
                    }
                }
                # Capsule Tenant CR
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "ops-com-ai-capsule-tenant"
                    spec.forProvider.manifest = {
                        apiVersion = "capsule.clastix.io/v1beta2"
                        kind = "Tenant"
                        metadata.name = "ops-com-ai"
                        spec.owners = [{kind = "Group", name = "ops-com-ai:tenant-admin"}]
                    }
                }
            ]
        }
    },

    # ==========================================================================
    # Test 2 (adopt mode): Zitadel Org has external-name annotation;
    # managementPolicies propagated.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "adopt-mode-external-name-org"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "ops-com-ai", namespace = "tenants"}
                spec = {
                    clusterName = "pat-local"
                    display = {name = "ops.com.ai", primaryDomain = "ops.com.ai"}
                    identity = {
                        zitadel = {
                            mode = "adopt"
                            adopt = {orgId = "373268222482392664"}
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
    # Test 3 (minimal — no capsule): only Namespace + Zitadel Org compose.
    # No Capsule Tenant CR.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "minimal-no-capsule"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "pat-brand", namespace = "tenants"}
                spec = {
                    clusterName = "pat-local"
                    type = "individual"
                    display = {
                        name = "Pat Scott"
                        primaryDomain = "patscott.io"
                        aliasDomains = ["patrickleescott.com"]
                    }
                    identity = {zitadel = {mode = "create"}}
                    capsule = {enabled = False}
                }
            }
            assertResources = [
                {
                    apiVersion = "kubernetes.m.crossplane.io/v1alpha1"
                    kind = "Object"
                    metadata.name = "pat-brand-namespace"
                    spec.forProvider.manifest.metadata.name = "pat-brand"
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
    # Test 4 (custom orgName + defaultProject + roles): override defaults.
    # ==========================================================================
    metav1alpha1.CompositionTest {
        metadata.name = "custom-org-project-roles"
        spec = {
            compositionPath = "apis/tenants/composition.yaml"
            xrdPath = "apis/tenants/definition.yaml"
            timeoutSeconds = 60
            validate = False
            xr = hopsv1alpha1.Tenant {
                metadata = {name = "thrivendale", namespace = "tenants"}
                spec = {
                    clusterName = "pat-local"
                    display = {name = "Thrivendale", primaryDomain = "thrivendale.com"}
                    identity = {
                        zitadel = {
                            mode = "create"
                            create = {orgName = "thrivendale-prod"}
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
