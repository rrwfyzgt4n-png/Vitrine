import XCTest

@MainActor
final class PhaseFourUITests: XCTestCase {
    func testMetadataOnlyModeKeepsCatalogBrowsable() {
        let app = launch(fixture: "metadataOnly")

        XCTAssertTrue(element("library.grid", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("status.locate", in: app).exists)
        XCTAssertTrue(book(1, in: app).exists)
    }

    func testKeyboardGridNavigationMovesSelection() {
        let app = launch(fixture: "available")
        XCTAssertTrue(selectBook(1, in: app))
        element("library.grid", in: app).typeKey(.rightArrow, modifierFlags: [])

        let selectionPublished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"),
            object: book(2, in: app)
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selectionPublished], timeout: 2), .completed)
    }

    func testInspectorDisclosureStatePersistsAcrossLaunches() {
        var app = launch(fixture: "available")
        XCTAssertTrue(selectBook(1, in: app))
        showInspector(in: app)

        let disclosure = app.disclosureTriangles["Book Details"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 3))
        if !isExpanded(disclosure) {
            disclosure.click()
        }
        XCTAssertTrue(isExpanded(disclosure))

        app.terminate()
        app = launch(fixture: "available")
        XCTAssertTrue(selectBook(1, in: app))
        showInspector(in: app)

        let restoredDisclosure = app.disclosureTriangles["Book Details"]
        XCTAssertTrue(restoredDisclosure.waitForExistence(timeout: 3))
        XCTAssertTrue(isExpanded(restoredDisclosure))
    }

    func testMissingFolderStatusClearsAfterReconnectionFixture() {
        var app = launch(fixture: "metadataOnly")
        XCTAssertTrue(element("status.locate", in: app).waitForExistence(timeout: 3))

        app.terminate()
        app = launch(fixture: "available")

        XCTAssertFalse(element("status.locate", in: app).exists)
        XCTAssertTrue(book(1, in: app).label.localizedCaseInsensitiveContains("cover available"))
    }

    func testConflictAndRepairEntryPointsRemainUserDirected() {
        var app = launch(fixture: "conflict")
        let keepMine = app.buttons["Keep My Changes"]
        XCTAssertTrue(keepMine.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Use Changes from Other Mac"].exists)
        XCTAssertTrue(app.buttons["Review Changes"].exists)

        app.terminate()
        app = launch(fixture: "repair")
        XCTAssertTrue(element("catalog.recovery", in: app).waitForExistence(timeout: 3))
    }

    func testCoreAccessibilityDescriptionAndSelection() {
        let app = launch(
            fixture: "available",
            additionalArguments: [
                "-AppleReduceMotion", "YES",
                "-AppleIncreaseContrast", "YES",
                "-AppleDifferentiateWithoutColor", "YES"
            ]
        )
        let firstBook = book(1, in: app)
        XCTAssertTrue(firstBook.waitForExistence(timeout: 3))
        XCTAssertTrue(firstBook.label.contains("Book 1"))
        XCTAssertTrue(firstBook.label.localizedCaseInsensitiveContains("cover available"))

        XCTAssertTrue(selectBook(1, in: app))
        XCTAssertTrue(firstBook.label.contains("Book 1 of 6"))
    }

    func testMainSceneRemainsSingleWindowAcrossReopen() {
        var app = launch(fixture: "available", ignorePersistentState: false)
        XCTAssertEqual(app.windows.count, 1)

        app.terminate()
        app = launch(fixture: "available", ignorePersistentState: false)
        XCTAssertEqual(app.windows.count, 1)

        app.typeKey("n", modifierFlags: .command)
        XCTAssertEqual(app.windows.count, 1)
    }

    func testUnsupportedSchemaIsReadOnly() {
        let app = launch(fixture: "unsupported")
        XCTAssertTrue(element("toolbar.refresh", in: app).waitForExistence(timeout: 3))
        XCTAssertFalse(element("toolbar.refresh", in: app).isEnabled)

        XCTAssertTrue(selectBook(1, in: app))
        showInspector(in: app)
        let editButton = element("inspector.edit", in: app)
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        XCTAssertFalse(editButton.isEnabled)
    }

    func testFiveThousandItemGridRemainsScrollable() {
        let app = launch(fixture: "scale5000")
        XCTAssertTrue(book(1, in: app).waitForExistence(timeout: 5))
        let startedAt = Date()

        book(1, in: app).click()
        element("library.grid", in: app).typeKey(.end, modifierFlags: [])

        XCTAssertTrue(book(5_000, in: app).waitForExistence(timeout: 10))
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 15)
    }

    private func launch(
        fixture: String,
        ignorePersistentState: Bool = true,
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["VITRINE_UI_TESTING"] = "1"
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-VitrineSkipRestoreLastCatalog", "YES",
            "-VitrineUITestFixture", fixture
        ]
        if ignorePersistentState {
            app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        }
        app.launchArguments += additionalArguments
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 5)
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func book(_ index: Int, in app: XCUIApplication) -> XCUIElement {
        let identifier = String(format: "book.00000000-0000-0000-0000-%012d", index)
        return element(identifier, in: app)
    }

    private func showInspector(in app: XCUIApplication) {
        if !element("inspector.edit", in: app).exists {
            element("toolbar.inspector", in: app).click()
        }
    }

    private func selectBook(_ index: Int, in app: XCUIApplication) -> Bool {
        let item = book(index, in: app)
        guard item.waitForExistence(timeout: 3) else { return false }
        item.click()
        let selectionPublished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"),
            object: item
        )
        return XCTWaiter.wait(for: [selectionPublished], timeout: 2) == .completed
    }

    private func isExpanded(_ disclosure: XCUIElement) -> Bool {
        if let value = disclosure.value as? NSNumber {
            return value.boolValue
        }
        return String(describing: disclosure.value) == "1"
    }
}
