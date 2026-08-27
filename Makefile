.PHONY: build test fixture replay-smoke adaptive-verification-test symbolication-crash-smoke pr-check host-integration-check simulator-check simulator-check-core simulator-repro-bundle-check physical-device-check ios-fixture ios-physical-fixture ios-fixture-smoke ios-debug-fixture-smoke ios-mcp-tool-smoke ios-ui-tree-smoke ios-arbitrary-ui-smoke ios-legacy-debug-smoke ios-legacy-debug-control-smoke ios-coredevice-debug-control-smoke ios-coredevice-lifecycle-smoke mcp-daemon-smoke mcp-domain-behavior-smoke mcp-mac-debug-workflow-smoke mcp-install-smoke codex-plugin-smoke menubar-build-smoke menubar-ui-smoke xcode-artifact-smoke xcode-test-smoke dwarf-smoke swift-ast-smoke performance-smoke performance-analysis-smoke swift-concurrency-graph-smoke runtime-diagnostics-smoke assembler-smoke control-flow-smoke memory-map-smoke dyld-cache-smoke simulator-environment-smoke repro-bundle-smoke signing-audit-smoke patch-workflow-smoke plugin-smoke plugin-xpc-smoke plugin-host-build-smoke workbench-build-smoke workbench-ui-smoke reverse-capability-smoke complex-debug-casebook complex-deadlock-casebook visual-regression-casebook complex-casebook package release-package check harness-check clean

build:
	swift build

test:
	swift test

pr-check: check

host-integration-check: build fixture
	./scripts/host_integration_check.sh

simulator-check: simulator-check-core simulator-repro-bundle-check

simulator-check-core: build
	./scripts/simulator_integration_check.sh

simulator-repro-bundle-check: build ios-fixture
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/repro_bundle_smoke.py

physical-device-check: build
	./scripts/physical_device_check.sh

fixture:
	./scripts/build_debug_fixture.sh

replay-smoke: build fixture
	python3 ./scripts/replay_smoke.py

adaptive-verification-test:
	PYTHONPATH=./scripts python3 -m unittest discover -s scripts -p 'test_adaptive_verification.py'

symbolication-crash-smoke: build
	python3 ./scripts/symbolication_crash_smoke.py

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

ios-arbitrary-ui-smoke: build ios-fixture
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/ios_arbitrary_ui_smoke.py

ios-physical-fixture:
	./scripts/build_ios_physical_fixture.sh

ios-legacy-debug-smoke: build ios-physical-fixture
	APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 python3 ./scripts/ios_legacy_debug_smoke.py

ios-legacy-debug-control-smoke: build ios-physical-fixture
	APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 APPLE_DEBUG_ALLOW_EVALUATE=1 APPLE_DEBUG_ALLOW_MEMORY_WRITE=1 python3 ./scripts/ios_legacy_debug_control_smoke.py

ios-coredevice-debug-control-smoke: build ios-physical-fixture
	APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 APPLE_DEBUG_ALLOW_EVALUATE=1 APPLE_DEBUG_ALLOW_MEMORY_WRITE=1 python3 ./scripts/ios_coredevice_debug_control_smoke.py

ios-coredevice-lifecycle-smoke: build ios-physical-fixture
	APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 python3 ./scripts/ios_coredevice_lifecycle_smoke.py

mcp-daemon-smoke: build
	python3 ./scripts/mcp_daemon_smoke.py

mcp-domain-behavior-smoke: build fixture
	python3 ./scripts/mcp_domain_behavior_smoke.py

mcp-mac-debug-workflow-smoke: build fixture
	python3 ./scripts/debug_fixture_smoke.py --extended --evidence-output .build/evidence/mcp-mac-debug-workflow.json

mcp-install-smoke: build
	./scripts/mcp_install_smoke.sh

codex-plugin-smoke: build
	python3 ./scripts/codex_plugin_smoke.py

menubar-build-smoke:
	./script/build_and_run.sh --verify

menubar-ui-smoke:
	./scripts/menubar_ui_smoke.sh

xcode-artifact-smoke: build
	APPLE_DEBUG_ALLOW_XCODE_BUILD=1 python3 ./scripts/xcode_artifact_smoke.py

dwarf-smoke: build
	APPLE_DEBUG_ALLOW_XCODE_BUILD=1 python3 ./scripts/dwarf_smoke.py

swift-ast-smoke: build
	python3 ./scripts/swift_ast_smoke.py

xcode-test-smoke: build
	APPLE_DEBUG_ALLOW_XCODE_BUILD=1 APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/xcode_test_smoke.py

performance-smoke: build
	APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 python3 ./scripts/performance_trace_smoke.py

performance-analysis-smoke: build
	APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 python3 ./scripts/performance_analysis_smoke.py

swift-concurrency-graph-smoke: build
	APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 python3 ./scripts/swift_concurrency_graph_smoke.py

runtime-diagnostics-smoke: build
	APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 python3 ./scripts/runtime_diagnostics_smoke.py

assembler-smoke: build
	python3 ./scripts/assembler_smoke.py

control-flow-smoke: build fixture
	python3 ./scripts/control_flow_smoke.py

memory-map-smoke: build
	APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 python3 ./scripts/memory_map_smoke.py

dyld-cache-smoke: build
	python3 ./scripts/dyld_cache_smoke.py

signing-audit-smoke: build
	python3 ./scripts/signing_audit_smoke.py

patch-workflow-smoke: build fixture
	python3 ./scripts/patch_workflow_smoke.py

simulator-environment-smoke: build
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/simulator_environment_smoke.py

repro-bundle-smoke: build ios-fixture
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/repro_bundle_smoke.py

plugin-smoke: build
	python3 ./scripts/plugin_smoke.py

plugin-xpc-smoke:
	python3 ./scripts/plugin_xpc_smoke.py

plugin-host-build-smoke:
	swift build --product apple-debug-plugin-host
	swift build --product apple-debug-plugin-xpc-service

workbench-build-smoke:
	swift build --product apple-debug-workbench

workbench-ui-smoke:
	./scripts/workbench_ui_smoke.sh

reverse-capability-smoke: build
	python3 ./scripts/reverse_capability_smoke.py

complex-debug-casebook: build
	python3 ./scripts/complex_debug_casebook.py

complex-deadlock-casebook: build
	python3 ./scripts/deadlock_casebook.py

visual-regression-casebook: build
	APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 python3 ./scripts/visual_regression_casebook.py

complex-casebook: complex-debug-casebook complex-deadlock-casebook visual-regression-casebook

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
