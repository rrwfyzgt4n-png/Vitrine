import XCTest

@MainActor
final class WelcomeFlowUITests: XCTestCase {
    func testWelcomeActionsAreVisible() {
        let app = launchCleanly()

        XCTAssertTrue(app.buttons["welcome.createCatalog"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["welcome.openCatalog"].exists)
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
