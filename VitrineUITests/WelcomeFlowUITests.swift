import XCTest

@MainActor
final class WelcomeFlowUITests: XCTestCase {
    func testWelcomeActionsAreVisible() {
        let app = launchCleanly()

        XCTAssertTrue(app.buttons["welcome.createCatalog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["welcome.openCatalog"].exists)
    }

    func testCreateButtonOpensFolderChooser() {
        let app = launchCleanly()

        app.buttons["welcome.createCatalog"].click()

        XCTAssertTrue(app.dialogs.firstMatch.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
    }

    func testOpenButtonOpensCatalogChooser() {
        let app = launchCleanly()

        app.buttons["welcome.openCatalog"].click()

        XCTAssertTrue(app.dialogs.firstMatch.waitForExistence(timeout: 3))
        app.typeKey(.escape, modifierFlags: [])
    }

    private func launchCleanly() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-VitrineSkipRestoreLastCatalog", "YES"
        ]
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 5)
        app.launch()
        return app
    }
}
