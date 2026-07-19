# Vitrine development

## Verification commands

Run the complete unit and UI test suite:

```sh
./script/test.sh
```

Build, verify the signature and required entitlements, launch the app, and confirm that its process remains running:

```sh
./script/build_and_run.sh --verify
```

Both commands must succeed before a core-phase handoff.

## Workstream ownership

The core-integrity workstream owns catalog access, scanning, reconciliation, saving, backups, external-change merging, recovery, the main catalog store, and their tests.

The parser and ancillary-metadata workstream owns:

- `Vitrine/Services/Metadata/FilenameMetadataParser.swift`
- `Vitrine/Models/FilenameMetadataSuggestion.swift`
- bibliographic parsing rules and fixtures
- metadata suggestion and enrichment field expansion
- related editor, inspector, localization, and accessibility copy

The following are shared integration surfaces and require coordination before their schemas or behavior change:

- `Vitrine/Models/BibliographicMetadata.swift`
- `Vitrine/Models/CatalogItem.swift`
- `Vitrine/Models/MetadataCandidate.swift`
- `Vitrine/Stores/CatalogStore.swift`
- Markdown parser and writer field mappings
- three-way merge field mappings

Every newly accepted bibliographic field must round-trip through Markdown, participate in merge and undo behavior, remain searchable where required, and retain localization and accessibility coverage. Core work must not rewrite filename parsing rules or parser fixtures during the separate parser workstream.
