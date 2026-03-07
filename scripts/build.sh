#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Pulse App — Build & Distribution Script
#
# Usage: ./scripts/build.sh <environment> <platform> [--distribute]
#
#   environment:  staging | production
#   platform:     android | ios
#   --distribute: Upload to Firebase App Distribution
#
# Examples:
#   ./scripts/build.sh staging android
#   ./scripts/build.sh production ios --distribute
# ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()   { echo -e "${BLUE}[pulse]${NC} $1"; }
ok()    { echo -e "${GREEN}[pulse]${NC} $1"; }
warn()  { echo -e "${YELLOW}[pulse]${NC} $1"; }
error() { echo -e "${RED}[pulse]${NC} $1"; }

usage() {
  cat <<EOF
Usage: ./scripts/build.sh <environment> <platform> [--distribute]

  environment:  staging | production
  platform:     android | ios
  --distribute: Upload to Firebase App Distribution after build

Examples:
  ./scripts/build.sh staging android
  ./scripts/build.sh staging ios --distribute
  ./scripts/build.sh production android --distribute
EOF
  exit 1
}

# ─────────────────────────────────────────────────────────
# Parse arguments
# ─────────────────────────────────────────────────────────

if [[ $# -lt 2 ]]; then
  usage
fi

ENVIRONMENT="$1"
PLATFORM="$2"
DISTRIBUTE=false

if [[ $# -ge 3 && "$3" == "--distribute" ]]; then
  DISTRIBUTE=true
fi

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
  error "Invalid environment: $ENVIRONMENT (must be 'staging' or 'production')"
  exit 1
fi

# Validate platform
if [[ "$PLATFORM" != "android" && "$PLATFORM" != "ios" ]]; then
  error "Invalid platform: $PLATFORM (must be 'android' or 'ios')"
  exit 1
fi

# ─────────────────────────────────────────────────────────
# Check prerequisites
# ─────────────────────────────────────────────────────────

log "Checking prerequisites..."

if ! command -v flutter &>/dev/null; then
  error "flutter is not installed or not in PATH"
  exit 1
fi

if [[ "$DISTRIBUTE" == true ]] && ! command -v firebase &>/dev/null; then
  error "firebase CLI is not installed (required for --distribute)"
  error "Install with: npm install -g firebase-tools"
  exit 1
fi

if [[ "$PLATFORM" == "ios" ]] && ! command -v xcodebuild &>/dev/null; then
  error "xcodebuild is not available (required for iOS builds)"
  exit 1
fi

# Check environment file exists
ENV_FILE="$PROJECT_DIR/.env.$ENVIRONMENT"
if [[ ! -f "$ENV_FILE" ]]; then
  error ".env.$ENVIRONMENT not found!"
  echo ""
  echo "  Create it by copying the template:"
  echo "    cp .env.$ENVIRONMENT.example .env.$ENVIRONMENT"
  echo "  Then fill in the actual values."
  exit 1
fi

# Branch warning for production distribution
if [[ "$DISTRIBUTE" == true && "$ENVIRONMENT" == "production" ]]; then
  CURRENT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  if [[ "$CURRENT_BRANCH" != "main" ]]; then
    warn "WARNING: Distributing production build from branch '$CURRENT_BRANCH' (not main)"
    warn "Press Enter to continue or Ctrl+C to abort..."
    read -r
  fi
fi

# ─────────────────────────────────────────────────────────
# Env swap with cleanup trap
# ─────────────────────────────────────────────────────────

ENV_TARGET="$PROJECT_DIR/.env"
ENV_BACKUP="$PROJECT_DIR/.env.bak"

cleanup() {
  if [[ -f "$ENV_BACKUP" ]]; then
    log "Restoring original .env from backup..."
    mv "$ENV_BACKUP" "$ENV_TARGET"
    ok "Original .env restored."
  fi
}
trap cleanup EXIT

# Back up existing .env (if it exists)
if [[ -f "$ENV_TARGET" ]]; then
  cp "$ENV_TARGET" "$ENV_BACKUP"
  log "Backed up .env → .env.bak"
fi

# Copy environment-specific file
cp "$ENV_FILE" "$ENV_TARGET"
ok "Copied .env.$ENVIRONMENT → .env"

# ─────────────────────────────────────────────────────────
# Quality gates
# ─────────────────────────────────────────────────────────

cd "$PROJECT_DIR"

log "Running quality gates..."

log "flutter analyze..."
flutter analyze --no-pub
ok "Analysis passed."

log "flutter test..."
flutter test --no-pub
ok "Tests passed."

# ─────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────

BUILD_ARGS=(--release --dart-define="SENTRY_ENVIRONMENT=$ENVIRONMENT")
ARTIFACT_PATH=""

if [[ "$PLATFORM" == "android" ]]; then
  if [[ "$ENVIRONMENT" == "staging" ]]; then
    log "Building Android APK (staging)..."
    flutter build apk "${BUILD_ARGS[@]}"
    ARTIFACT_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
  else
    log "Building Android App Bundle (production)..."
    flutter build appbundle "${BUILD_ARGS[@]}"
    ARTIFACT_PATH="$PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
  fi
elif [[ "$PLATFORM" == "ios" ]]; then
  log "Building iOS IPA..."
  flutter build ipa "${BUILD_ARGS[@]}"
  # IPA output path varies; find the most recent one
  ARTIFACT_PATH=$(find "$PROJECT_DIR/build/ios/ipa" -name "*.ipa" -type f 2>/dev/null | head -1)
fi

if [[ -n "$ARTIFACT_PATH" && -f "$ARTIFACT_PATH" ]]; then
  ok "Build complete: $ARTIFACT_PATH"
else
  warn "Build completed but artifact path could not be determined."
  warn "Check the build output above for the artifact location."
fi

# ─────────────────────────────────────────────────────────
# Distribution (Firebase App Distribution)
# ─────────────────────────────────────────────────────────

if [[ "$DISTRIBUTE" == true ]]; then
  if [[ -z "$ARTIFACT_PATH" || ! -f "$ARTIFACT_PATH" ]]; then
    error "Cannot distribute: build artifact not found"
    exit 1
  fi

  # Auto-generate release notes
  GIT_SHA=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  GIT_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  BUILD_TIME=$(date '+%Y-%m-%d %H:%M')
  RELEASE_NOTES="$ENVIRONMENT build
Branch: $GIT_BRANCH
Commit: $GIT_SHA
Built: $BUILD_TIME"

  # Firebase app IDs from firebase_options.dart
  if [[ "$PLATFORM" == "android" ]]; then
    FIREBASE_APP_ID="1:696556381830:android:99b989136ad24d478f1307"
  else
    FIREBASE_APP_ID="1:696556381830:ios:21088707eeea3a0a8f1307"
  fi

  log "Uploading to Firebase App Distribution..."
  log "App ID: $FIREBASE_APP_ID"
  log "Release notes: $RELEASE_NOTES"

  firebase appdistribution:distribute "$ARTIFACT_PATH" \
    --app "$FIREBASE_APP_ID" \
    --groups "testers" \
    --release-notes "$RELEASE_NOTES"

  ok "Distributed to Firebase App Distribution!"
fi

# ─────────────────────────────────────────────────────────
# Done (cleanup runs via trap)
# ─────────────────────────────────────────────────────────

echo ""
ok "Build pipeline complete: $ENVIRONMENT / $PLATFORM"
if [[ "$DISTRIBUTE" == true ]]; then
  ok "Artifact distributed to Firebase App Distribution."
fi
