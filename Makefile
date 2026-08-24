.PHONY: build test fixture ios-fixture ios-fixture-smoke check harness-check clean

build:
	swift build

test:
	swift test

fixture:
	./scripts/build_debug_fixture.sh

ios-fixture:
	./scripts/build_ios_fixture.sh

ios-fixture-smoke:
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 ./scripts/ios_fixture_smoke.sh

check:
	./scripts/check.sh

harness-check:
	./scripts/harness_check.sh

clean:
	swift package clean
