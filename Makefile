APP        := Unbroken
BUNDLE     := dist/$(APP).app
BINARY     := .build/release/$(APP)
WIDGET_BIN := .build/release/UnbrokenWidget
APPEX      := $(BUNDLE)/Contents/Extensions/UnbrokenWidget.appex
CLANG_MODULE_CACHE_PATH ?= .build/clang-module-cache

.PHONY: build test app run clean embed-widget

build:
	mkdir -p $(CLANG_MODULE_CACHE_PATH)
	CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) swift build

test:
	swift test

release:
	mkdir -p $(CLANG_MODULE_CACHE_PATH)
	CLANG_MODULE_CACHE_PATH=$(CLANG_MODULE_CACHE_PATH) swift build --disable-sandbox -c release

app: release
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Support/Info.plist $(BUNDLE)/Contents/
	cp Support/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	cp Support/Fonts/*.ttf $(BUNDLE)/Contents/Resources/
	$(MAKE) embed-widget
	codesign --force --sign - $(BUNDLE)

run: app
	open $(BUNDLE)

# `unbroken` CLI: build and stage into dist/ (install by copying to PATH).
cli: release
	cp .build/release/unbroken-cli dist/unbroken

# WidgetKit extension packaging.
#
# Assembles a real .appex into the app bundle: the release widget binary +
# WidgetInfo.plist (EXAppExtensionAttributes / widgetkit-extension), ad-hoc
# signed. The app is re-signed afterwards to seal the nested code.
#
# REALITY CHECK: this is a best-effort REAL WidgetKit appex, but the app is
# ad-hoc signed and distributed outside the App Store. macOS may decline to
# surface an ad-hoc-signed widget in the gallery even when the appex is
# structurally valid and codesign-verified — real registration typically needs
# a Developer ID / provisioning profile. See the notes in `embed-widget`.
#
# `embed-widget` never fails the build: if the widget binary is missing it
# prints a TODO and leaves the app bundle intact and green.
embed-widget:
	@if [ ! -x "$(WIDGET_BIN)" ]; then \
		echo "TODO(widget): $(WIDGET_BIN) not found — run 'make release' first."; \
		echo "TODO(widget): skipping .appex embed; app bundle left unchanged."; \
	else \
		rm -rf "$(APPEX)"; \
		mkdir -p "$(APPEX)/Contents/MacOS" "$(APPEX)/Contents/Resources/Fonts"; \
		cp "$(WIDGET_BIN)" "$(APPEX)/Contents/MacOS/UnbrokenWidget"; \
		cp Support/WidgetInfo.plist "$(APPEX)/Contents/Info.plist"; \
		cp Support/Fonts/*.ttf "$(APPEX)/Contents/Resources/Fonts/"; \
		codesign --force --sign - "$(APPEX)"; \
		echo "Embedded + signed $(APPEX)"; \
	fi

# Standalone entry point. Builds the release binaries, then ensures a full app
# bundle exists with the widget embedded and both signatures sealed.
widget: release
	@if [ ! -d "$(BUNDLE)" ]; then \
		echo "No app bundle yet — building it (embeds the widget)…"; \
		$(MAKE) app; \
	else \
		$(MAKE) embed-widget; \
		codesign --force --sign - "$(BUNDLE)"; \
	fi

clean:
	rm -rf .build dist
