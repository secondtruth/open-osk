# OpenOSK build helpers.
#
# The extra framework/rpath flags for `test` are only needed when the active
# developer directory (xcode-select -p) is the Command Line Tools: CLT ships
# Swift Testing outside the default search paths. With an Xcode toolchain
# selected, a plain `swift test` works.

# Where SwiftPM keeps build products. Point it at a local directory when the
# checkout lives on a synced or network volume (Synology Drive, iCloud, SMB):
# codesign rejects the extended attributes such volumes attach, which fails
# `make test`. Example: make test SCRATCH_PATH=~/Library/Caches/OpenOSK
SCRATCH_PATH ?= .build
export SCRATCH_PATH
SWIFT_FLAGS := --scratch-path "$(SCRATCH_PATH)"

DEVELOPER_DIR := $(shell xcode-select -p 2>/dev/null)
CLT_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_TESTING_LIB := /Library/Developer/CommandLineTools/Library/Developer/usr/lib
TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT_FRAMEWORKS) \
	-Xlinker -F -Xlinker $(CLT_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(CLT_TESTING_LIB)

.PHONY: build release run test bundle clean

build:
	swift build $(SWIFT_FLAGS)

release:
	swift build -c release $(SWIFT_FLAGS)

run: build
	"$(SCRATCH_PATH)/debug/openosk"

test:
	@if echo "$(DEVELOPER_DIR)" | grep -q CommandLineTools && [ -d "$(CLT_FRAMEWORKS)" ]; then \
		swift test $(SWIFT_FLAGS) $(TEST_FLAGS); \
	else \
		swift test $(SWIFT_FLAGS); \
	fi

bundle: release
	scripts/bundle.sh

clean:
	swift package $(SWIFT_FLAGS) clean
	rm -rf build
