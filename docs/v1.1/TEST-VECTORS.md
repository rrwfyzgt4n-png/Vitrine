# Vitrine 1.1 remediation-vector evidence

This is the portable evidence map for the 24 structured test vectors supplied
with the Vitrine 1.1 remediation package. A vector is marked automated only
when its named proof runs through `script/test.sh` or the headless
release-candidate scale suite.

`CurrentCorpusIntegrationTests` and
`FilenameParserDifferentialTests.testMountedCorpusAuditReportsAllDifferencesAndValidatesSpans`
are optional machine-local diagnostics. They are deliberately excluded from
this table and from portable coverage claims.

## Portable automated vectors

| Vector | Required outcome | Portable proof |
| --- | --- | --- |
| T11-001 | A metadata edit is durable before termination completes | `ApplicationContractTests.testTerminationWaitsForFlushAndCompletesOnce`; `SaveCoordinatorTests.testFlushSkipsDebounceAndPersistsQueuedSave` |
| T11-002 | A failed edit save changes neither catalog nor undo | `SaveCoordinatorTests.testFailedEditedItemSaveLeavesCatalogAndUndoUnchanged` |
| T11-003 | An unresolved 3×3 fingerprint cluster removes nothing | `CatalogReconcilerTests.testThreeUnresolvedItemsAndSourcesBecomeOneAmbiguousCluster` |
| T11-004 | A metadata-only record survives a complete refresh | `CatalogReconcilerTests.testMetadataOnlyRecordSurvivesCompleteRefreshWhenCoverRemainsAbsent` |
| T11-005 | Escaping relative cover paths are rejected everywhere | `CoverPathResolverTests.testTraversalAbsoluteMalformedAndRootPathsAreRejected`; `CoverPathResolverTests.testInteractiveCoverActionsReportInvalidCatalogPath` |
| T11-006 | Replacing another catalog preserves its own identity | `SaveCoordinatorTests.testConfirmedDifferentCatalogReplacementBacksUpOldIdentity` |
| T11-007 | Complex conflict values remain localized and readable | `CatalogMergeValueFormatterTests.testSpecializedBibliographicValuesUseLocalizedDisplayConventions`; `CatalogMergeValueFormatterTests.testEveryMergeFieldHasAReadableSampleWithoutSwiftDebugSyntax` |
| T11-008 | Dynamic or incomplete localization fails verification | `script/audit_localizations.sh`; `LocalizationTests.testEveryCatalogEntryHasFrenchAndCanadianFrenchLocalization` |
| T11-009 | A non-title edit preserves 5,000-item search and sort output | `Phase5PerformanceTests.testRepeatedSearchQueriesOverFiveThousandItemsPreserveResultsAfterNonTitleEdit` |
| T11-010 | A uniquely reappearing source restores availability | `CatalogReconcilerTests.testMetadataOnlyRecordBecomesAvailableWhenItsSourceReappears` |
| T11-011 | An in-root symlink escaping the root is rejected | `CoverPathResolverTests.testSymlinkEscapeIsRejected` |
| T11-012 | A malformed destination is not silently overwritten | `SaveCoordinatorTests.testConfirmedMalformedReplacementPreservesRawBytesInOrphanArea` |
| T11-013 | Repeated 5,000-item searches preserve exact results | `Phase5PerformanceTests.testRepeatedSearchQueriesOverFiveThousandItemsPreserveResultsAfterNonTitleEdit` |
| T11-014 | Parser optimization preserves the portable golden corpus | `FilenameParserDifferentialTests.testPortableGoldenCorpusHasNoUnapprovedValueDifferences`; `FilenameParserDifferentialTests.testOldAndNewFiveThousandRecordMetrics` |
| T11-015 | Optimized mixed-diff application matches the baseline | `Phase5PerformanceTests.testFiveThousandRecordDiffMatchesLegacyBehaviorAndReportsMetric` |
| T11-016 | CRLF, CR, and LF notes round-trip identically | `MarkdownWriterTests.testFinderAndPersonalNotesNormalizeEveryLineEndingWithoutChangingStyles` |
| T11-017 | Reviewed suggestions and an external edit converge without rollback | `MetadataIntegrationTests.testReviewedSuggestionsMergeAnExternalCatalogChangeWithoutRollback`; `CatalogFilePresenterTests.testRapidEventsRemainOrderedUntilTheStoreCanRereadState` |
| T11-018 | Catalog relocation can preserve existing cover access | `SecurityScopedBookmarkStoreTests.testUnavailableFolderDoesNotEraseRememberedAccess` |
| T11-019 | An explicit save wakes debounce and persists the newest state | `SaveCoordinatorTests.testExplicitSaveWakesMetadataDebounceAndPersistsNewestSnapshot` |
| T11-020 | A save queued during disk coordination runs afterward | `SaveCoordinatorTests.testSaveArrivingDuringInFlightWriteRunsAfterItsPredecessor` |
| T11-021 | Unknown front matter, prose, and record lines survive round-trip | `MarkdownRoundTripTests.testKnownAndUnknownRecordDataSurviveRoundTrip` |
| T11-022 | Local edit, external edit, deletion, and additions merge safely | `CatalogMergeServiceTests.testDeletionConflictResolutionPreservesIndependentEditsAndUnrelatedAdditions` |
| T11-023 | Duplicate record IDs remain diagnostic and non-overwriting | `MarkdownParserTests.testDuplicateRecordIDCannotReplaceFirstAcceptedRecord` |
| T11-024 | Restore after rename refreshes the baseline for a later edit | `SaveCoordinatorTests.testRestoreAfterRenameRefreshesBaselineForTheNextEdit` |

## Manual product acceptance

The structured remediation vectors above are portable and automated. They do
not replace the hardware and human-observation rows in
`V1-RELEASE-CHECKLIST.md`. iCloud transport, removable-volume behavior,
two-device conflict transport, browser fallback, VoiceOver operation, and
appearance review require a dated hands-on record before the release gate can
be called complete.
