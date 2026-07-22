#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="$ROOT_DIR/.build/ReleaseCandidate/$STAMP"
DERIVED_DATA="$REPORT_DIR/DerivedData"
SCALE_LOG="$REPORT_DIR/scale-tests.log"
SUMMARY="$REPORT_DIR/summary.txt"
CONFIRM_SCREEN_CONTROL="${1:-}"
SCALE_SENTINEL="$ROOT_DIR/.build/RunReleaseScale"

mkdir -p "$REPORT_DIR"
trap 'rm -f "$SCALE_SENTINEL"' EXIT

{
  echo "Vitrine V1 release-candidate verification"
  echo "Started: $STAMP"
  echo "Report directory: $REPORT_DIR"
} >"$SUMMARY"

echo "Running localization, unit, concurrency and integrity tests."
"$ROOT_DIR/script/test.sh"
echo "Headless suite: passed" >>"$SUMMARY"

echo "Generating and measuring synthetic 1,000-, 2,500- and 5,000-cover libraries."
touch "$SCALE_SENTINEL"
if ! VITRINE_RUN_RELEASE_SCALE=1 \
  VITRINE_RELEASE_SCALE_COUNTS=1000,2500,5000 \
  xcodebuild test \
    -project "$ROOT_DIR/Vitrine.xcodeproj" \
    -scheme Vitrine \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:VitrineTests/ReleaseCandidateScaleTests \
    >"$SCALE_LOG" 2>&1; then
  tail -120 "$SCALE_LOG" >&2
  exit 1
fi
rm -f "$SCALE_SENTINEL"
rg 'VITRINE_RELEASE_METRIC' "$SCALE_LOG" | tee -a "$SUMMARY"
echo "Scale and source-integrity suite: passed" >>"$SUMMARY"

if [[ "$CONFIRM_SCREEN_CONTROL" == "--confirm-screen-control" ]]; then
  echo "Warning: the UI and signed-launch checks will now take keyboard focus." >&2
  ui_status=0
  if "$ROOT_DIR/script/test_ui.sh" --confirm-screen-control; then
    echo "UI suite: passed" >>"$SUMMARY"
  else
    ui_status=$?
    echo "UI suite: failed or environment-blocked (exit $ui_status)" >>"$SUMMARY"
  fi

  VITRINE_DERIVED_DATA_PATH="$REPORT_DIR/SignedDerivedData" \
    "$ROOT_DIR/script/build_and_run.sh" --verify
  echo "Clean signed build and launch: passed" >>"$SUMMARY"
else
  echo "UI suite and signed launch: not run (screen-control confirmation not supplied)" >>"$SUMMARY"
  echo "Run '$ROOT_DIR/script/release_candidate.sh --confirm-screen-control' during an acceptable interruption window." >&2
fi

echo "Completed: $(date -u +%Y%m%dT%H%M%SZ)" >>"$SUMMARY"
echo "Release-candidate evidence: $SUMMARY"

if [[ "${ui_status:-0}" -ne 0 ]]; then
  echo "UI verification did not pass; see the xcodebuild result bundle." >&2
  exit "$ui_status"
fi
