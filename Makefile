SWIFT       ?= swift
SWIFTLINT   ?= swiftlint
SWIFTFORMAT ?= swiftformat
CODESIGN    ?= codesign

APP_NAME   := Mote
BUNDLE_ID  := com.samzong.mote
BUILD_DIR  := .build
APP_BUNDLE := /Applications/$(APP_NAME).app
APP_ICON   := Resources/AppIcon.icns
ARCH       ?= arm64

DMG_DIR     := $(BUILD_DIR)/dmg
DMG_STAGING := $(DMG_DIR)/staging
DMG_PATH    := $(BUILD_DIR)/$(APP_NAME)-$(ARCH).dmg

CODE_SIGN_IDENTITY    ?= -
CODE_SIGN_REQUIREMENT := =designated => identifier "$(BUNDLE_ID)"
CODE_SIGN             := $(CODESIGN) --force --sign $(CODE_SIGN_IDENTITY) --requirements '$(CODE_SIGN_REQUIREMENT)'

BOLD  := \033[1m
CYAN  := \033[36m
GREEN := \033[32m
RESET := \033[0m

.DEFAULT_GOAL := help

# -- Development --------------------------------------------------------------

.PHONY: build app run test lint format check

build: ## Build debug artifacts
	$(SWIFT) build -c debug

app: ## Build the debug app product
	$(SWIFT) build -c debug --product $(APP_NAME)

run: app ## Run the debug app product
	$(BUILD_DIR)/debug/$(APP_NAME)

test: ## Run tests
	$(SWIFT) test

lint: ## Run SwiftLint
	$(SWIFTLINT) lint --quiet

format: ## Format sources and tests
	$(SWIFTFORMAT) Sources Tests

check: ## Run build, lint, and tests
	@printf '\n$(BOLD)[1/3] Building$(RESET)\n'
	@$(MAKE) --no-print-directory build
	@printf '\n$(BOLD)[2/3] Running lint$(RESET)\n'
	@$(MAKE) --no-print-directory lint
	@printf '\n$(BOLD)[3/3] Running tests$(RESET)\n'
	@$(MAKE) --no-print-directory test
	@printf '\n$(GREEN)[ok] All checks passed$(RESET)\n\n'

# -- Packaging ----------------------------------------------------------------

.PHONY: dmg install uninstall

dmg: ## Build an ad-hoc signed DMG
	$(SWIFT) build -c release --arch $(ARCH) --product $(APP_NAME)
	rm -rf $(DMG_STAGING)
	mkdir -p $(DMG_STAGING)/$(APP_NAME).app/Contents/MacOS
	mkdir -p $(DMG_STAGING)/$(APP_NAME).app/Contents/Resources
	cp $$($(SWIFT) build -c release --arch $(ARCH) --product $(APP_NAME) --show-bin-path)/$(APP_NAME) $(DMG_STAGING)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(DMG_STAGING)/$(APP_NAME).app/Contents/Info.plist
	cp $(APP_ICON) $(DMG_STAGING)/$(APP_NAME).app/Contents/Resources/AppIcon.icns
	$(CODE_SIGN) $(DMG_STAGING)/$(APP_NAME).app
	ln -s /Applications $(DMG_STAGING)/Applications
	rm -f $(DMG_PATH)
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(DMG_STAGING) \
		-ov -format UDZO \
		$(DMG_PATH)
	rm -rf $(DMG_DIR)
	@printf "DMG created: %s\n" "$(DMG_PATH)"

install: ## Install an ad-hoc signed app bundle to /Applications
	$(SWIFT) build -c release --arch $(ARCH) --product $(APP_NAME)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $$($(SWIFT) build -c release --arch $(ARCH) --product $(APP_NAME) --show-bin-path)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp $(APP_ICON) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	$(CODE_SIGN) $(APP_BUNDLE)
	@printf "Installed to %s\n" "$(APP_BUNDLE)"

uninstall: ## Remove the installed app bundle
	rm -rf $(APP_BUNDLE)
	@printf "Removed %s\n" "$(APP_BUNDLE)"

# -- Maintenance --------------------------------------------------------------

.PHONY: clean

clean: ## Remove SwiftPM build artifacts
	$(SWIFT) package clean
	rm -rf $(BUILD_DIR)

# -- Help ---------------------------------------------------------------------

.PHONY: help

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "; printf "\n$(BOLD)mote$(RESET) - macOS text rewrite app\n"} \
		/^# -- / {n = $$0; gsub(/(^# -- | -+$$)/, "", n); printf "\n$(BOLD)%s$(RESET)\n", n} \
		/^[a-zA-Z_-]+:.*## / {printf "  $(CYAN)make %-10s$(RESET) %s\n", $$1, $$2} \
		END {printf "\n"}' $(MAKEFILE_LIST)
