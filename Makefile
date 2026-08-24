.PHONY: build test fixture ios-fixture ios-fixture-smoke ios-debug-fixture-smoke ios-mcp-tool-smoke ios-ui-tree-smoke xcode-artifact-smoke xcode-test-smoke dwarf-smoke performance-smoke package release-package check harness-check clean

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

ios-debug-fixture-smoke:
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 ./scripts/ios_debug_fixture_smoke.sh

ios-mcp-tool-smoke:
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/ios_mcp_tool_smoke.py

ios-ui-tree-smoke:
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/ios_ui_tree_smoke.py

xcode-artifact-smoke: build
	APPLE_DEBUG_ALLOW_XCODE_BUILD=1 python3 ./scripts/xcode_artifact_smoke.py

dwarf-smoke: build
	APPLE_DEBUG_ALLOW_XCODE_BUILD=1 python3 ./scripts/dwarf_smoke.py

xcode-test-smoke: build
	APPLE_DEBUG_ALLOW_XCODE_BUILD=1 APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/xcode_test_smoke.py

performance-smoke: build
	APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 python3 ./scripts/performance_trace_smoke.py

package:
	./scripts/package_macos.sh

release-package:
	./scripts/release_macos.sh

check:
	./scripts/check.sh

harness-check:
	./scripts/harness_check.sh

clean:
	swift package clean
