# ─────────────────────────────────────────────────────────
# Pulse App — Build & Distribution Targets
# ─────────────────────────────────────────────────────────

SHELL := /bin/bash

# Build only
build-staging-android:
	./scripts/build.sh staging android

build-staging-ios:
	./scripts/build.sh staging ios

build-production-android:
	./scripts/build.sh production android

build-production-ios:
	./scripts/build.sh production ios

# Build + distribute to Firebase App Distribution
distribute-staging-android:
	./scripts/build.sh staging android --distribute

distribute-staging-ios:
	./scripts/build.sh staging ios --distribute

distribute-production-android:
	./scripts/build.sh production android --distribute

distribute-production-ios:
	./scripts/build.sh production ios --distribute

# Quality gates only (analyze + test)
check:
	flutter analyze --no-pub
	flutter test --no-pub

.PHONY: build-staging-android build-staging-ios build-production-android build-production-ios \
        distribute-staging-android distribute-staging-ios distribute-production-android distribute-production-ios \
        check
