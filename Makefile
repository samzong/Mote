APP_NAME := Mote
CLI_NAME := motectl
BUILD_DIR := .build
PROJECT_DIR := $(shell pwd)
HOST_ARCH := $(shell uname -m)
USER_APPLICATIONS := $(HOME)/Applications
INSTALL_PATH := $(USER_APPLICATIONS)/$(APP_NAME).app
DEBUG_APP := $(BUILD_DIR)/debug/$(APP_NAME).app
RELEASE_APP := $(BUILD_DIR)/release/$(APP_NAME).app

.PHONY: help
help:
	@printf "Usage:\n"
	@printf "  make build\n"
	@printf "  make run\n"
	@printf "  make test\n"
	@printf "  make install\n"
	@printf "  make clean\n"
	@printf "  make run-cli ARGS=\"doctor\"\n"

.PHONY: build
build:
	swift build -c debug

.PHONY: run
run:
	./Scripts/compile_and_run.sh debug

.PHONY: run-cli
run-cli:
	swift run $(CLI_NAME) $(ARGS)

.PHONY: test
test:
	swift test

.PHONY: install
install:
	swift build -c release
	./Scripts/package_app.sh release
	mkdir -p $(USER_APPLICATIONS)
	rm -rf $(INSTALL_PATH)
	cp -R $(RELEASE_APP) $(INSTALL_PATH)

.PHONY: clean
clean:
	swift package clean
	rm -rf $(BUILD_DIR)
