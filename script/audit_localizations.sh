#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG_PATH="$ROOT_DIR/Vitrine/Resources/Localizable.xcstrings"
AUDIT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vitrine-localization-audit.XXXXXX")"

cleanup() {
  if [[ -d "$AUDIT_DIR" ]]; then
    rm -r "$AUDIT_DIR"
  fi
}
trap cleanup EXIT

sources=()
while IFS= read -r source; do
  sources+=("$source")
done < <(rg --files "$ROOT_DIR/Vitrine" -g '*.swift')

if ! xcrun xcstringstool extract \
  --SwiftUI \
  --modern-localizable-strings \
  -s text \
  -s detail \
  -s comparison \
  -s suggestionRow \
  -s suggestionSummaryRow \
  -s healthRow \
  --output-format xcstrings \
  --output-directory "$AUDIT_DIR" \
  "${sources[@]}" \
  >"$AUDIT_DIR/extraction-output.txt" \
  2>"$AUDIT_DIR/extraction-errors.txt"; then
  cat "$AUDIT_DIR/extraction-output.txt" >&2
  cat "$AUDIT_DIR/extraction-errors.txt" >&2
  exit 1
fi

EXTRACTED_PATH="$AUDIT_DIR/Localizable.xcstrings"
EXTRACTED_KEYS="$AUDIT_DIR/extracted-keys.txt"
CATALOG_KEYS="$AUDIT_DIR/catalog-keys.txt"
MISSING_KEYS="$AUDIT_DIR/missing-keys.txt"

normalize_placeholders() {
  sed -E 's/%([0-9]+\$)?(arg|@|lld|llu|ld|lu|d|u|f|s)/%#/g'
}

jq -r '.strings | keys[]' "$EXTRACTED_PATH" | normalize_placeholders | sort -u > "$EXTRACTED_KEYS"
jq -r '.strings | keys[]' "$CATALOG_PATH" | normalize_placeholders | sort -u > "$CATALOG_KEYS"
comm -23 "$EXTRACTED_KEYS" "$CATALOG_KEYS" > "$MISSING_KEYS"

if [[ -s "$MISSING_KEYS" ]]; then
  echo "SwiftUI localization keys missing from Localizable.xcstrings:" >&2
  sed 's/^/  - /' "$MISSING_KEYS" >&2
  exit 1
fi

echo "Localization audit passed: every extracted SwiftUI key is catalogued."
