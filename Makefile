.PHONY: all build install clean test register restart-ql

PROJECT_NAME = QLYAML
SCHEME = YAMLQuickLook
CONFIG = Release
BUILD_DIR = build
APP_NAME = YAML QuickLook.app
DEST_APP = /Applications/$(APP_NAME)

all: test build install register restart-ql

test:
	@echo "🧪 Running unit tests..."
	@xcrun swiftc -o /tmp/run_tests Shared/*.swift Tests/YAMLTokenizerTests.swift && /tmp/run_tests && rm /tmp/run_tests

generate:
	@echo "⚙️  Generating Xcode project with XcodeGen..."
	@xcodegen generate

build: generate
	@echo "🔨 Building $(PROJECT_NAME) ($(CONFIG))..."
	@xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) build

install:
	@echo "📦 Installing $(APP_NAME) to /Applications..."
	@mkdir -p /Applications
	@rm -rf "$(DEST_APP)"
	@TARGET_DIR=$$(xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SCHEME) -configuration $(CONFIG) -showBuildSettings 2>/dev/null | awk -F ' = ' '/TARGET_BUILD_DIR/ {print $$2}' | tr -d '\r'); \
	BUILT_APP="$$TARGET_DIR/$(APP_NAME)"; \
	if [ -d "$$BUILT_APP" ]; then \
		cp -R "$$BUILT_APP" /Applications/; \
		echo "✅ Installed from $$BUILT_APP to /Applications/"; \
	else \
		echo "❌ Could not find built app at $$BUILT_APP"; exit 1; \
	fi

register:
	@echo "🔌 Registering Quick Look extensions with pluginkit..."
	@pluginkit -r com.2b3pro.qlyaml.thumbnail 2>/dev/null || true
	@pluginkit -a "$(DEST_APP)/Contents/PlugIns/YAMLPreviewExtension.appex"
	@pluginkit -e use -i com.2b3pro.qlyaml.preview
	@echo "✅ Registered extensions:"
	@pluginkit -m -v | grep -i 2b3pro

restart-ql:
	@echo "🔄 Resetting macOS QuickLook daemon and caches..."
	@qlmanage -r
	@qlmanage -r cache
	@killall Finder 2>/dev/null || true
	@echo "✅ QuickLook daemon cache and Finder refreshed!"

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf QLYAML.xcodeproj
