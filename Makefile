CLI_NAME := motectl
BUILD_DIR := .build

.PHONY: help
help:
	@printf "Usage:\n"
	@printf "  make build\n"
	@printf "  make run ARGS=\"doctor\"\n"
	@printf "  make test\n"
	@printf "  make lint\n"
	@printf "  make format\n"
	@printf "  make clean\n"

.PHONY: build
build:
	swift build -c debug

.PHONY: app
app:
	swift build -c debug --product Mote

.PHONY: run
run:
	swift run $(CLI_NAME) $(ARGS)

.PHONY: run-app
run-app: app
	.build/debug/Mote

.PHONY: test
test:
	swift test

.PHONY: lint
lint:
	swiftlint lint --quiet

.PHONY: format
format:
	swiftformat Sources Tests

.PHONY: clean
clean:
	swift package clean
	rm -rf $(BUILD_DIR)
