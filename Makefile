.PHONY: build run clean test release install help

# Default target
.DEFAULT_GOAL := help

# Build configuration
SCHEME = ScreenTimeCapsule
BUILD_DIR = .build
APP_NAME = ScreenTimeCapsule.app
EXECUTABLE = $(BUILD_DIR)/release/ScreenTimeCapsule

help: ## Show this help message
	@echo "ScreenTimeCapsule Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the project in debug mode
	@echo "Building ScreenTimeCapsule (debug)..."
	swift build

release: ## Build the project in release mode
	@echo "Building ScreenTimeCapsule (release)..."
	swift build -c release

run: build ## Build and run the application
	@echo "Running ScreenTimeCapsule..."
	swift run

test: ## Run tests
	@echo "Running tests..."
	swift test

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf $(BUILD_DIR)
	rm -rf $(APP_NAME)
	rm -f *.zip

app-bundle: release ## Create macOS app bundle
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_NAME)/Contents/MacOS"
	@mkdir -p "$(APP_NAME)/Contents/Resources"
	@cp $(EXECUTABLE) "$(APP_NAME)/Contents/MacOS/"
	@cp Resources/Info.plist "$(APP_NAME)/Contents/"
	@cp Resources/ScreenTimeCapsule.entitlements "$(APP_NAME)/Contents/"
	@echo "App bundle created: $(APP_NAME)"

sign: app-bundle ## Sign the application (requires Developer ID)
	@echo "Signing application..."
	@if [ -z "$(SIGNING_IDENTITY)" ]; then \
		echo "Error: SIGNING_IDENTITY not set"; \
		echo "Usage: make sign SIGNING_IDENTITY='Developer ID Application: Your Name (TEAM_ID)'"; \
		exit 1; \
	fi
	codesign --deep --force --verify --verbose \
		--sign "$(SIGNING_IDENTITY)" \
		--options runtime \
		--entitlements Resources/ScreenTimeCapsule.entitlements \
		$(APP_NAME)
	@echo "Verifying signature..."
	codesign --verify --verbose $(APP_NAME)

zip: app-bundle ## Create a zip archive of the app
	@echo "Creating zip archive..."
	ditto -c -k --keepParent $(APP_NAME) ScreenTimeCapsule.zip
	@echo "Archive created: ScreenTimeCapsule.zip"

install: app-bundle ## Install the app to /Applications
	@echo "Installing to /Applications..."
	@sudo rm -rf /Applications/$(APP_NAME)
	@sudo cp -R $(APP_NAME) /Applications/
	@echo "Installed to /Applications/$(APP_NAME)"

uninstall: ## Uninstall the app from /Applications
	@echo "Uninstalling from /Applications..."
	@sudo rm -rf /Applications/$(APP_NAME)
	@echo "Uninstalled"

update-deps: ## Update Swift package dependencies
	@echo "Updating dependencies..."
	swift package update

resolve-deps: ## Resolve Swift package dependencies
	@echo "Resolving dependencies..."
	swift package resolve

reset-deps: ## Reset package dependencies
	@echo "Resetting dependencies..."
	rm -rf .build
	rm -f Package.resolved
	swift package resolve

format: ## Format Swift code (requires swiftformat)
	@echo "Formatting code..."
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat .; \
	else \
		echo "swiftformat not found. Install with: brew install swiftformat"; \
	fi

lint: ## Lint Swift code (requires swiftlint)
	@echo "Linting code..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint; \
	else \
		echo "swiftlint not found. Install with: brew install swiftlint"; \
	fi

check: lint test ## Run linter and tests

xcode: ## Open project in Xcode
	@echo "Opening in Xcode..."
	open Package.swift

docs: ## Generate documentation
	@echo "Generating documentation..."
	swift package generate-documentation

.PHONY: all
all: clean release app-bundle ## Clean, build release, and create app bundle
	@echo "Build complete!"
