.PHONY: build test check harness-check clean

build:
	swift build

test:
	swift test

check:
	./scripts/check.sh

harness-check:
	./scripts/harness_check.sh

clean:
	swift package clean
