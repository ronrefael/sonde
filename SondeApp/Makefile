.PHONY: build bundle install launch dmg clean

APP_NAME = SondeApp
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
INFO_PLIST_SRC = Sources/SondeApp/Info.plist

build:
	swift build -c release

bundle: build
	@echo "Creating app bundle..."
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	cp "$$(swift build -c release --show-bin-path)/$(APP_NAME)" $(MACOS_DIR)/$(APP_NAME)
	@# Copy Info.plist and ensure required keys are present
	plutil -convert xml1 $(INFO_PLIST_SRC) -o $(CONTENTS_DIR)/Info.plist
	@# Ensure LSUIElement is true
	/usr/libexec/PlistBuddy -c "Set :LSUIElement true" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" $(CONTENTS_DIR)/Info.plist
	@# Ensure CFBundleIdentifier
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier dev.sonde.app" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string dev.sonde.app" $(CONTENTS_DIR)/Info.plist
	@# Ensure CFBundleName
	/usr/libexec/PlistBuddy -c "Set :CFBundleName Sonde" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundleName string Sonde" $(CONTENTS_DIR)/Info.plist
	@# Ensure CFBundleDisplayName
	/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Sonde" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Sonde" $(CONTENTS_DIR)/Info.plist
	@# Ensure NSUserNotificationUsageDescription
	/usr/libexec/PlistBuddy -c "Set :NSUserNotificationUsageDescription 'Sonde sends notifications when your Claude Code usage approaches limits.'" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :NSUserNotificationUsageDescription string 'Sonde sends notifications when your Claude Code usage approaches limits.'" $(CONTENTS_DIR)/Info.plist
	@# Ensure LSMinimumSystemVersion
	/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 13.0" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" $(CONTENTS_DIR)/Info.plist
	@# Ensure CFBundleExecutable
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(APP_NAME)" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" $(CONTENTS_DIR)/Info.plist
	@# Ensure CFBundlePackageType
	/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" $(CONTENTS_DIR)/Info.plist
	@# Sign with entitlements (disables sandbox so app can read ~/.claude/)
	codesign --force --sign - --entitlements Sources/SondeApp/SondeApp.entitlements $(MACOS_DIR)/$(APP_NAME)
	@echo "App bundle created at $(APP_BUNDLE)"

install: bundle
	@echo "Installing to /Applications..."
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "Installed to /Applications/$(APP_NAME).app"

launch: bundle
	open $(APP_BUNDLE)

dmg: bundle
	@echo "Creating DMG..."
	rm -f $(BUILD_DIR)/Sonde.dmg
	hdiutil create -volname "Sonde" \
		-srcfolder $(APP_BUNDLE) \
		-ov -format UDZO \
		$(BUILD_DIR)/Sonde.dmg
	@echo "DMG created at $(BUILD_DIR)/Sonde.dmg"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)
	@echo "Cleaned."
