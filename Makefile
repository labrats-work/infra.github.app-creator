.PHONY: help validate lint list create create-org exchange clean check-deps

MANIFEST ?=
ORG ?=
CODE ?=

SHELL := /bin/bash
SCRIPTS := create-app.sh exchange-code.sh
EXAMPLES := $(wildcard examples/*.json)

help: ## Show all available targets
	@echo "infra.github.app-creator"
	@echo "========================"
	@echo ""
	@echo "Usage: make <target> [OPTIONS]"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Options:"
	@echo "  MANIFEST=<path>    Path to manifest JSON (for create/create-org)"
	@echo "  ORG=<name>         GitHub organization name (for create-org)"
	@echo "  CODE=<code>        GitHub manifest code (for exchange)"
	@echo ""
	@echo "Examples:"
	@echo "  make create MANIFEST=examples/ci-automation.json"
	@echo "  make create-org ORG=labrats-work MANIFEST=examples/ci-automation.json"
	@echo "  make exchange CODE=01234567-89ab-cdef-0123-456789abcdef"

validate: ## Validate scripts (bash -n) and all example JSONs (jq)
	@echo "Validating shell scripts..."
	@fail=0; \
	for script in $(SCRIPTS); do \
		if bash -n "$$script"; then \
			echo "  ✓ $$script"; \
		else \
			echo "  ✗ $$script"; \
			fail=1; \
		fi; \
	done; \
	echo ""; \
	echo "Validating example manifests..."; \
	for json in $(EXAMPLES); do \
		if jq empty "$$json" 2>/dev/null; then \
			echo "  ✓ $$json"; \
		else \
			echo "  ✗ $$json"; \
			fail=1; \
		fi; \
	done; \
	echo ""; \
	if [ "$$fail" -eq 1 ]; then \
		echo "Validation failed."; \
		exit 1; \
	else \
		echo "All validations passed."; \
	fi

lint: validate ## Alias for validate

list: ## List available template manifests with descriptions
	@echo "Available template manifests:"
	@echo ""
	@for json in $(EXAMPLES); do \
		name=$$(jq -r '.name' "$$json"); \
		desc=$$(jq -r '.description' "$$json"); \
		printf "  %-45s %s\n" "$$json" "$$name"; \
		echo "    $$desc"; \
		echo ""; \
	done

create: ## Create a GitHub App from a manifest (interactive if no MANIFEST given)
ifeq ($(MANIFEST),)
	@echo "Available manifests:"; \
	echo ""; \
	files=(); \
	i=1; \
	for json in $(EXAMPLES); do \
		name=$$(jq -r '.name' "$$json"); \
		printf "  %d) %-40s %s\n" "$$i" "$$json" "$$name"; \
		files+=("$$json"); \
		i=$$((i + 1)); \
	done; \
	echo ""; \
	read -p "Select manifest [1-$${#files[@]}]: " choice; \
	idx=$$((choice - 1)); \
	if [ "$$idx" -lt 0 ] || [ "$$idx" -ge "$${#files[@]}" ]; then \
		echo "Invalid selection."; \
		exit 1; \
	fi; \
	selected="$${files[$$idx]}"; \
	echo ""; \
	./create-app.sh "$$selected"
else
	./create-app.sh $(MANIFEST)
endif

create-org: ## Create an org-level GitHub App (requires ORG and MANIFEST)
ifeq ($(ORG),)
	@echo "Error: ORG is required"
	@echo "Usage: make create-org ORG=<org-name> MANIFEST=<path>"
	@exit 1
endif
ifeq ($(MANIFEST),)
	@echo "Error: MANIFEST is required"
	@echo "Usage: make create-org ORG=<org-name> MANIFEST=<path>"
	@exit 1
endif
	./create-app.sh $(MANIFEST) $(ORG)

exchange: ## Exchange a GitHub manifest code for credentials
ifeq ($(CODE),)
	@echo "Error: CODE is required"
	@echo "Usage: make exchange CODE=<code>"
	@exit 1
endif
	./exchange-code.sh $(CODE)

clean: ## Remove generated credentials and temp files
	@echo "Removing generated credentials and temp files..."
	@rm -f github-app-private-key.pem
	@rm -f github-app-credentials.txt
	@rm -f github-app-*.html
	@rm -f *.pem
	@rm -f *.tmp
	@echo "Done."

check-deps: ## Verify required dependencies (jq, curl, bash) are available
	@echo "Checking dependencies..."
	@fail=0; \
	for cmd in bash curl jq; do \
		if command -v "$$cmd" > /dev/null 2>&1; then \
			version=$$($$cmd --version 2>&1 | head -1); \
			echo "  ✓ $$cmd — $$version"; \
		else \
			echo "  ✗ $$cmd — NOT FOUND"; \
			fail=1; \
		fi; \
	done; \
	echo ""; \
	if [ "$$fail" -eq 1 ]; then \
		echo "Missing dependencies. Install them before continuing."; \
		exit 1; \
	else \
		echo "All dependencies available."; \
	fi
