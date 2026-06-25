# aws-landing-zone-terraform — operator entrypoints.
#
# Quality loop (no AWS calls):   make check
# Per-environment workflow:      make plan ENV=dev   /   make apply ENV=prod
#
# ENV selects environments/$(ENV). Backend values are injected at init time via
# a partial backend config file (backend.hcl) so no account/bucket name is ever
# committed. Copy backend.hcl.example -> environments/$(ENV)/backend.hcl first.

ENV     ?= dev
ENV_DIR := environments/$(ENV)
BACKEND := backend.hcl

# Roots that hold a Terraform state (validated/scanned independently).
ROOTS := bootstrap global environments/dev environments/prod

.DEFAULT_GOAL := help

.PHONY: help check fmt fmt-check validate lint scan init plan apply destroy guard-env

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

## ---- Quality loop (static only) -------------------------------------------

check: fmt-check validate lint scan ## Run the full static quality loop

fmt: ## Format all Terraform files in place
	terraform fmt -recursive

fmt-check: ## Verify formatting without writing
	terraform fmt -check -recursive

validate: ## terraform validate on every root (offline, no backend)
	@set -e; for d in $(ROOTS); do \
		echo "==> validate $$d"; \
		terraform -chdir=$$d init -backend=false -input=false -no-color >/dev/null; \
		terraform -chdir=$$d validate -no-color; \
	done

lint: ## Run tflint recursively
	tflint --recursive

scan: ## Run checkov security/compliance scan
	checkov -d . --compact --quiet

## ---- Per-environment workflow ---------------------------------------------

guard-env:
	@test -n "$(filter $(ENV),dev prod)" || { echo "ENV must be dev or prod"; exit 1; }

init: guard-env ## Init an env with the partial S3 backend (needs $(ENV_DIR)/$(BACKEND))
	terraform -chdir=$(ENV_DIR) init -backend-config=$(BACKEND) -input=false

plan: guard-env ## Plan changes for ENV (read-only)
	terraform -chdir=$(ENV_DIR) plan -input=false

apply: guard-env ## Apply changes for ENV
	terraform -chdir=$(ENV_DIR) apply -input=false

destroy: guard-env ## Destroy ENV resources
	terraform -chdir=$(ENV_DIR) destroy -input=false
