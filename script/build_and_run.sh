#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Vitrine"
BUNDLE_ID="com.etienne.Vitrine"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${VITRINE_DERIVED_DATA_PATH:-$ROOT_DIR/.build/DerivedData}"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/Vitrine.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
ENTITLEMENTS_PLIST="$(mktemp /tmp/vitrine-entitlements.XXXXXX.plist)"
trap '/bin/rm -f "$ENTITLEMENTS_PLIST"' EXIT
/usr/bin/codesign -d --entitlements :- "$APP_BUNDLE" >"$ENTITLEMENTS_PLIST" 2>/dev/null
for required_entitlement in \
  com.apple.security.app-sandbox \
  com.apple.security.files.user-selected.read-write \
  com.apple.security.files.bookmarks.app-scope \
  com.apple.security.network.client; do
  if ! /usr/libexec/PlistBuddy -c "Print :$required_entitlement" "$ENTITLEMENTS_PLIST" 2>/dev/null | /usr/bin/grep -qx true; then
    echo "Vitrine is missing required entitlement: $required_entitlement" >&2
    exit 1
  fi
done

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
