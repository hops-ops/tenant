SHELL := /bin/bash

PACKAGE ?= tenant
# Default XRD_DIR for legacy single-API targets; multi-API targets derive per-example.
XRD_DIR := apis/tenants
COMPOSITION := $(XRD_DIR)/composition.yaml
DEFINITION := $(XRD_DIR)/definition.yaml
EXAMPLE_DEFAULT := examples/tenants/standard.yaml
RENDER_TESTS := $(wildcard tests/test-*)
E2E_TESTS := $(wildcard tests/e2etest-*)

# Multi-API support: examples/<apiplural>/<example>.yaml maps to apis/<apiplural>/.
api-dir = apis/$(word 2,$(subst /, ,$(1)))

clean:
	rm -rf _output
	rm -rf .up

build:
	up project build

# Examples list - mirrors GitHub Actions workflow
# Format: example_path::observed_resources_path (observed_resources_path is optional)
EXAMPLES := \
    examples/tenants/standard.yaml:: \
    examples/tenants/adopt.yaml:: \
    examples/tenants/minimal.yaml::

# Render all examples (parallel execution, output shown per-job when complete)
render\:all:
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		api_dir=$$(echo "$$example" | awk -F/ '{print "apis/" $$2}'); \
		composition="$$api_dir/composition.yaml"; \
		definition="$$api_dir/definition.yaml"; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				echo "=== Rendering $$example with observed-resources $$observed ==="; \
				up composition render --xrd=$$definition $$composition $$example --observed-resources=$$observed; \
			else \
				echo "=== Rendering $$example (api=$$api_dir) ==="; \
				up composition render --xrd=$$definition $$composition $$example; \
			fi; \
			echo "" \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

# Validate all examples
validate\:all:
	@tmpdir=$$(mktemp -d); \
	pids=""; \
	for entry in $(EXAMPLES); do \
		example=$${entry%%::*}; \
		observed=$${entry#*::}; \
		api_dir=$$(echo "$$example" | awk -F/ '{print "apis/" $$2}'); \
		composition="$$api_dir/composition.yaml"; \
		definition="$$api_dir/definition.yaml"; \
		outfile="$$tmpdir/$$(echo $$entry | tr '/:' '__')"; \
		( \
			if [ -n "$$observed" ]; then \
				echo "=== Validating $$example with observed-resources $$observed ==="; \
				up composition render --xrd=$$definition $$composition $$example \
					--observed-resources=$$observed --include-full-xr --quiet | \
					crossplane beta validate $$api_dir --error-on-missing-schemas -; \
			else \
				echo "=== Validating $$example (api=$$api_dir) ==="; \
				up composition render --xrd=$$definition $$composition $$example \
					--include-full-xr --quiet | \
					crossplane beta validate $$api_dir --error-on-missing-schemas -; \
			fi; \
			echo "" \
		) > "$$outfile" 2>&1 & \
		pids="$$pids $$!:$$outfile"; \
	done; \
	failed=0; \
	for pair in $$pids; do \
		pid=$${pair%%:*}; \
		outfile=$${pair#*:}; \
		if ! wait $$pid; then failed=1; fi; \
		cat "$$outfile"; \
	done; \
	rm -rf "$$tmpdir"; \
	exit $$failed

# Shorthand aliases
.PHONY: render validate
render: ; @$(MAKE) 'render:all'
validate: ; @$(MAKE) 'validate:all'

# Single example targets
render\:%:
	@example="examples/tenants/$*.yaml"; \
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example

validate\:%:
	@example="examples/tenants/$*.yaml"; \
	up composition render --xrd=$(DEFINITION) $(COMPOSITION) $$example \
		--include-full-xr --quiet | \
		crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

test:
	up test run $(RENDER_TESTS)

e2e:
	up test run $(E2E_TESTS) --e2e

publish:
	@if [ -z "$(tag)" ]; then echo "Error: tag is not set. Usage: make publish tag=<version>"; exit 1; fi
	up project build --push --tag $(tag)
