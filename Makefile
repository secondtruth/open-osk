# OpenOSK build helpers.
#
# The extra framework/rpath flags for `test` are only needed when the active
# developer directory (xcode-select -p) is the Command Line Tools: CLT ships
# Swift Testing outside the default search paths. With an Xcode toolchain
# selected, a plain `swift test` works.

DEVELOPER_DIR := $(shell xcode-select -p 2>/dev/null)
CLT_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_TESTING_LIB := /Library/Developer/CommandLineTools/Library/Developer/usr/lib
TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT_FRAMEWORKS) \
	-Xlinker -F -Xlinker $(CLT_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(CLT_TESTING_LIB)

.PHONY: build release run test bundle clean

build:
	swift build

release:
	swift build -c release

run: build
	.build/debug/openosk

test:
	@if echo "$(DEVELOPER_DIR)" | grep -q CommandLineTools && [ -d "$(CLT_FRAMEWORKS)" ]; then \
		swift test $(TEST_FLAGS); \
	else \
		swift test; \
	fi

bundle: release
	scripts/bundle.sh

clean:
	swift package clean
	rm -rf build
