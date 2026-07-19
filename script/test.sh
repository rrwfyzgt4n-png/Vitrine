#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

xcodebuild test \
  -quiet \
  -project "$ROOT_DIR/Vitrine.xcodeproj" \
  -scheme Vitrine \
  -destination "platform=macOS" \
  -derivedDataPath "$ROOT_DIR/.build/TestDerivedData"
