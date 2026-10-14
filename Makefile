# ChillRar build (works with Command Line Tools only – no Xcode / SwiftPM needed)
#
#   make            -> build app bundle + CLI (release, arm64)
#   make app        -> build/ChillRar.app
#   make cli        -> build/chillrar
#   make test       -> run self tests + integration tests
#   make install    -> copy ChillRar.app to /Applications
#   make clean

export COPYFILE_DISABLE := 1

ARCH        ?= arm64
MIN_MACOS   ?= 13.0
TARGET      := $(ARCH)-apple-macosx$(MIN_MACOS)
BUILD       := build
SWIFTFLAGS  ?= -O -whole-module-optimization
SWIFTC      := xcrun swiftc -target $(TARGET) $(SWIFTFLAGS)

# Some Command Line Tools upgrades leave a stale usr/include/swift/module.modulemap
# that redefines 'SwiftBridging' and breaks every Swift build. Hide it with a
# VFS overlay instead of requiring `sudo rm`.
STALE_MODMAP := /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap
ifneq ($(and $(wildcard $(STALE_MODMAP)),$(wildcard /Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap)),)
OVERLAY     := $(BUILD)/clt-overlay.yaml
SWIFTC      += -vfsoverlay $(OVERLAY) -Xcc -ivfsoverlay -Xcc $(OVERLAY)
endif
CC          := xcrun clang -target $(TARGET) -O2

CUNRAR_INC  := Sources/CUnrar/include
UNRAR_LIB   := Vendor/lib/libunrar.a
SHIM_OBJ    := $(BUILD)/shim.o
RARKIT_LIB  := $(BUILD)/libRarKit.a
RARKIT_MOD  := $(BUILD)/RarKit.swiftmodule
RARKIT_SRC  := $(wildcard Sources/RarKit/*.swift)
APP_SRC     := $(wildcard Sources/ChillRar/*.swift)
CLI_SRC     := $(wildcard Sources/chillrar-cli/*.swift)

APP_BUNDLE  := $(BUILD)/ChillRar.app
LINK_LIBS   := $(RARKIT_LIB) $(SHIM_OBJ) -L Vendor/lib -lunrar -lc++

.PHONY: all app cli unrar test install clean run

all: app cli

unrar: $(UNRAR_LIB)
$(UNRAR_LIB):
	Scripts/build_unrar.sh

$(SHIM_OBJ): Sources/CUnrar/shim.c $(CUNRAR_INC)/CUnrar.h
	@mkdir -p $(BUILD)
	$(CC) -I $(CUNRAR_INC) -c $< -o $@

$(BUILD)/clt-overlay.yaml: Scripts/toolchain/overlay.yaml.in
	@mkdir -p $(BUILD)
	sed "s#@ROOT@#$(CURDIR)#" $< > $@

$(RARKIT_LIB): $(RARKIT_SRC) $(SHIM_OBJ) $(UNRAR_LIB) $(OVERLAY)
	@mkdir -p $(BUILD)
	$(SWIFTC) -parse-as-library -module-name RarKit -I $(CUNRAR_INC) \
		-emit-library -static -emit-module -emit-module-path $(RARKIT_MOD) \
		$(RARKIT_SRC) -o $@

cli: $(BUILD)/chillrar
$(BUILD)/chillrar: $(CLI_SRC) $(RARKIT_LIB)
	$(SWIFTC) -parse-as-library -I $(BUILD) -I $(CUNRAR_INC) $(CLI_SRC) $(LINK_LIBS) -o $@
	find $(BUILD) -name "._*" -delete
	codesign --force --sign - $@

app: $(APP_BUNDLE)
$(APP_BUNDLE): $(APP_SRC) $(RARKIT_LIB) Resources/Info.plist Resources/AppIcon.icns
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	$(SWIFTC) -parse-as-library -I $(BUILD) -I $(CUNRAR_INC) $(APP_SRC) $(LINK_LIBS) \
		-o $(APP_BUNDLE)/Contents/MacOS/ChillRar
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	find $(APP_BUNDLE) -name "._*" -delete
	codesign --force --deep --sign - $(APP_BUNDLE)
	@# Let LaunchServices know about document types / services.
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f $(APP_BUNDLE) || true
	@echo "Built $(APP_BUNDLE)"

$(BUILD)/selftest: Tests/SelfTest/main.swift $(RARKIT_LIB)
	$(SWIFTC) -I $(BUILD) -I $(CUNRAR_INC) $< $(LINK_LIBS) -o $@

test: $(BUILD)/selftest cli
	$(BUILD)/selftest
	Scripts/integration_test.sh

run: app
	open $(APP_BUNDLE)

install: app
	rm -rf /Applications/ChillRar.app
	cp -R $(APP_BUNDLE) /Applications/
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ChillRar.app
	/System/Library/CoreServices/pbs -update || true

clean:
	rm -rf $(BUILD) .build
