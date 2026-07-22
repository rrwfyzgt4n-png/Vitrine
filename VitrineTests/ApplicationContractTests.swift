import Foundation
import XCTest

final class ApplicationContractTests: XCTestCase {
    func testMainSceneIsSingletonAndRestorable() throws {
        let source = try projectSource("Vitrine/App/VitrineApp.swift")

        XCTAssertTrue(source.contains("Window(\"Vitrine\", id: \"main\")"))
        XCTAssertTrue(source.contains(".restorationBehavior(.automatic)"))
        XCTAssertFalse(source.contains("WindowGroup"))
        XCTAssertTrue(source.contains("Window(\"About Vitrine\", id: \"about\")"))
        XCTAssertTrue(source.contains(".restorationBehavior(.disabled)"))
    }

    func testRequiredFileLibraryBookAndViewCommandsAreDeclared() throws {
        let source = try projectSource("Vitrine/App/AppCommands.swift")
        let requiredCommands = [
            "Create New Catalog…", "Open Catalog…", "Save Now", "Export Catalog Copy…",
            "Reveal Catalog in Finder", "Open Catalog in Text Editor",
            "Refresh Covers", "Locate Your Cover Folder…", "Show Books Needing Review",
            "Check Catalog Health…", "Restore Previous Catalog Version…",
            "Rebuild Cover Information…", "Show Local Backups in Finder", "Export Diagnostic Report…",
            "Open Cover", "Quick Look", "Reveal Cover in Finder", "Find Book Details Online…",
            "Edit Book Details…", "Copy Title", "Copy ISBN", "Keep Without Cover",
            "Remove from Catalog…", "Focus Search", "Hide Inspector", "Show Inspector",
            "Increase Cover Size", "Decrease Cover Size", "Reset Cover Size",
        ]

        for command in requiredCommands {
            XCTAssertTrue(source.contains("\"\(command)\""), "Missing command declaration: \(command)")
        }
    }

    private func projectSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }
}
