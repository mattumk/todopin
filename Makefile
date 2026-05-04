APP    = TodoPin
BUILD  = .build
BUNDLE = $(BUILD)/$(APP).app
BIN    = $(BUNDLE)/Contents/MacOS/$(APP)
SRCS   = $(wildcard *.swift)
ARCH   = $(shell uname -m)
SDK    = $(shell xcrun --sdk macosx --show-sdk-path)
TARGET = $(ARCH)-apple-macosx13.0

.PHONY: build run clean

build: $(BIN)

$(BIN): $(SRCS) Info.plist
	@mkdir -p $(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUNDLE)/Contents/Resources
	swiftc $(SRCS) \
	    -o $(BIN) \
	    -target $(TARGET) \
	    -sdk $(SDK) \
	    -Onone
	@cp Info.plist $(BUNDLE)/Contents/Info.plist
	@if [ -f AppIcon.icns ]; then cp AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns; fi
	@echo "✓ $(APP).app prêt dans $(BUNDLE)"

run: build
	@open $(BUNDLE)

clean:
	@rm -rf $(BUILD)
	@echo "✓ Nettoyé"
