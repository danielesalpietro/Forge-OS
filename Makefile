# Forge-OS build entry points. Run `make help`.
SHELL := /bin/bash
.DEFAULT_GOAL := help

include build/forge.env
export

PROFILE     ?= baseline
DOCKER      ?= docker
BUILDER     := $(BUILDER_IMAGE):$(BUILDER_TAG)
ISO         := build/out/forge-os-$(FORGE_VERSION)-$(PROFILE)-$(ARCH).iso
TTY         := $(shell [ -t 0 ] && echo -it || echo -i)

# Environment forwarded into the builder container (secrets never live in the repo).
PASS_ENV := PROFILE FORGE_ADMIN_SSH_KEY FORGE_LUKS_PASSPHRASE FORGE_ADMIN_PASSWORD_HASH \
            FORGE_HOSTNAME FORGE_ADMIN_USER FORGE_TIMEZONE FORGE_KERNEL_ARGS \
            FORGE_TPM_ENROLL FORGE_TPM_PCRS FORGE_TANG_URLS FORGE_CIS_LEVEL \
            FORGE_IDENTITY_BACKEND FORGE_REBOOT_AFTER_FIRSTBOOT \
            FORGE_SKIP_GPG FORGE_SKIP_REPO FORGE_SKIP_GALAXY
DOCKER_RUN := $(DOCKER) run --rm $(TTY) $(foreach v,$(PASS_ENV),-e $(v)) \
              -v "$(CURDIR):/src" -w /src $(BUILDER)

.PHONY: help builder builder-shell iso iso-local packages lint validate test-kvm clean distclean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'
	@echo; echo "  Profiles: $(notdir $(wildcard autoinstall/profiles/*))   (PROFILE=$(PROFILE))"

builder: ## Build the builder container image
	$(DOCKER) build -t $(BUILDER) build/

builder-shell: ## Open a shell in the builder container
	$(DOCKER_RUN) bash

iso: ## Build the autoinstall ISO inside the builder container (needs FORGE_ADMIN_SSH_KEY)
	$(DOCKER_RUN) build/scripts/build-iso.sh

iso-local: ## Build the ISO with host tools (xorriso, envsubst, apt-get as root, ...)
	build/scripts/build-iso.sh

packages: ## Only rebuild the offline package repository into the work tree
	$(DOCKER_RUN) build/scripts/20-build-package-repo.sh

lint: ## shellcheck, yamllint, ansible-lint, autoinstall schema validation
	build/scripts/lint.sh

lint-docker: ## Same as lint, inside the builder container
	$(DOCKER_RUN) build/scripts/lint.sh

test-kvm: ## End-to-end install test in QEMU/KVM with Secure Boot + swtpm (needs the ISO)
	tests/kvm/run-iso.sh "$(ISO)"

clean: ## Remove work tree and outputs
	rm -rf build/work build/out

distclean: clean ## Also drop the cached base ISO
	rm -rf build/cache
