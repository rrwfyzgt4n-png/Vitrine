#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" != "--confirm-screen-control" ]]; then
  echo "UI tests are interactive: they launch Vitrine and take keyboard focus." >&2
  echo "Run './script/test_ui.sh --confirm-screen-control' only when screen interruption is acceptable." >&2
  exit 2
fi

echo "Warning: Vitrine UI tests will now launch the app and take keyboard focus." >&2

xcodebuild test \
  -quiet \
  -project "$ROOT_DIR/Vitrine.xcodeproj" \
  -scheme "Vitrine UI Tests" \
  -destination "platform=macOS" \
  -derivedDataPath "$ROOT_DIR/.build/UITestDerivedData"
