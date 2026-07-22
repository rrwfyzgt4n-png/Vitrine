#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Running Vitrine's non-interactive unit and integration tests."

"$ROOT_DIR/script/audit_localizations.sh"

xcodebuild test \
  -quiet \
  -project "$ROOT_DIR/Vitrine.xcodeproj" \
  -scheme Vitrine \
  -destination "platform=macOS" \
  -derivedDataPath "$ROOT_DIR/.build/TestDerivedData" \
  -only-testing:VitrineTests
