.PHONY: build bundle install install-fonts launch dmg clean

BINARY_NAME = SondeApp
FONT_DIR = ../fonts
APP_NAME = Sonde
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
	cp "$$(swift build -c release --show-bin-path)/$(BINARY_NAME)" $(MACOS_DIR)/$(BINARY_NAME)
	@# Copy app icon and bundled resources (fonts)
	cp AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns
	@# Copy Swift Package bundled resources if they exist
	-cp -R "$$(swift build -c release --show-bin-path)/SondeApp_SondeApp.bundle" $(RESOURCES_DIR)/ 2>/dev/null
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
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(BINARY_NAME)" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(BINARY_NAME)" $(CONTENTS_DIR)/Info.plist
	@# Ensure CFBundlePackageType
	/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" $(CONTENTS_DIR)/Info.plist
	@# Ensure CFBundleIconFile
	/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" $(CONTENTS_DIR)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" $(CONTENTS_DIR)/Info.plist
	@# Sign with entitlements (disables sandbox so app can read ~/.claude/)
	codesign --force --sign - --entitlements Sources/SondeApp/SondeApp.entitlements $(MACOS_DIR)/$(BINARY_NAME)
	@echo "App bundle created at $(APP_BUNDLE)"

install-fonts:
	@if ls ~/Library/Fonts/*NerdFont* >/dev/null 2>&1; then \
		echo "Nerd Font already installed — skipping."; \
	else \
		echo ""; \
		echo "Sonde uses Nerd Font icons in the terminal statusline."; \
		echo "Install MesloLGS Nerd Font Mono to ~/Library/Fonts? [Y/n] "; \
		read ans; \
		case "$$ans" in \
			[nN]*) echo "Skipped — statusline will show text-only (no icons).";; \
			*) mkdir -p ~/Library/Fonts && \
			   cp $(FONT_DIR)/MesloLGSNerdFontMono-*.ttf ~/Library/Fonts/ && \
			   echo "Installed MesloLGS Nerd Font Mono to ~/Library/Fonts/." && \
			   echo "Set your terminal font to 'MesloLGS Nerd Font Mono' for icons.";; \
		esac; \
	fi

install: bundle install-fonts
	@echo "Installing to /Applications..."
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R $(APP_BUNDLE) "/Applications/$(APP_NAME).app"
	@echo "Installed to /Applications/$(APP_NAME).app"

launch: bundle
	open $(APP_BUNDLE)

dmg: bundle
	@echo "Creating DMG with drag-to-Applications..."
	rm -f $(BUILD_DIR)/Sonde.dmg
	rm -rf $(BUILD_DIR)/dmg-staging
	mkdir -p $(BUILD_DIR)/dmg-staging
	cp -R $(APP_BUNDLE) $(BUILD_DIR)/dmg-staging/
	ln -s /Applications $(BUILD_DIR)/dmg-staging/Applications
	hdiutil create -volname "Sonde" \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDZO \
		$(BUILD_DIR)/Sonde.dmg
	rm -rf $(BUILD_DIR)/dmg-staging
	@echo "DMG created at $(BUILD_DIR)/Sonde.dmg"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)
	@echo "Cleaned."
