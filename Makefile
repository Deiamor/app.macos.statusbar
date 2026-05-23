APP_NAME   = StatusBar
RELEASE    = .build/release/$(APP_NAME)
BUNDLE     = $(APP_NAME).app

.PHONY: build bundle run install clean

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(RELEASE) $(BUNDLE)/Contents/MacOS/
	cp Info.plist $(BUNDLE)/Contents/
	codesign --sign - --force $(BUNDLE)
	@echo "Built: $(BUNDLE)"

run: bundle
	open $(BUNDLE)

install: bundle
	mkdir -p ~/Applications
	rm -rf ~/Applications/$(BUNDLE)
	cp -r $(BUNDLE) ~/Applications/
	@echo "Installed → ~/Applications/$(BUNDLE)"

clean:
	swift package clean
	rm -rf $(BUNDLE)
