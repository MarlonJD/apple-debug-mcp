.PHONY: build test fixture check harness-check clean

build:
	swift build

test:
	swift test

fixture:
	./scripts/build_debug_fixture.sh

check:
	./scripts/check.sh

harness-check:
	./scripts/harness_check.sh

clean:
	swift package clean
