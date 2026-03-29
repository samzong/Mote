APP_NAME := Mote
BUILD_DIR := .build
APP_BUNDLE := $(HOME)/Applications/$(APP_NAME).app

.PHONY: help
help:
	@printf "Usage:\n"
	@printf "  make build\n"
	@printf "  make run\n"
	@printf "  make test\n"
	@printf "  make lint\n"
	@printf "  make format\n"
	@printf "  make install\n"
	@printf "  make uninstall\n"
	@printf "  make clean\n"

.PHONY: build
build:
	swift build -c debug

.PHONY: app
app:
	swift build -c debug --product Mote

.PHONY: run
run: app
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

.PHONY: install
install:
	swift build -c release --product $(APP_NAME)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BUILD_DIR)/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(APP_BUNDLE)
	@printf "Installed to %s\n" "$(APP_BUNDLE)"

.PHONY: uninstall
uninstall:
	rm -rf $(APP_BUNDLE)
	@printf "Removed %s\n" "$(APP_BUNDLE)"

.PHONY: clean
clean:
	swift package clean
	rm -rf $(BUILD_DIR)
