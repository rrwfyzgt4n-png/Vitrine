import AppKit
import Foundation
import XCTest
@testable import Vitrine

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

    @MainActor
    func testTerminationWaitsForFlushAndCompletesOnce() async {
        let controller = ApplicationTerminationController(timeout: .seconds(1))
        let completed = expectation(description: "Termination completed")
        var flushCount = 0
        var completionCount = 0

        let firstReply = controller.requestTermination {
            flushCount += 1
            try await Task.sleep(for: .milliseconds(30))
        } completion: { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected flush failure: \(error)")
            }
            completionCount += 1
            completed.fulfill()
        }
        let repeatedReply = controller.requestTermination {
            flushCount += 1
        } completion: { _ in
            completionCount += 1
        }

        XCTAssertEqual(firstReply, .terminateLater)
        XCTAssertEqual(repeatedReply, .terminateLater)
        await fulfillment(of: [completed], timeout: 1)
        XCTAssertEqual(flushCount, 1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertFalse(controller.isTerminationPending)
    }

    @MainActor
    func testTerminationFailureCancelsTermination() async {
        let controller = ApplicationTerminationController(timeout: .seconds(1))
        let completed = expectation(description: "Termination failure returned")
        var didFail = false

        _ = controller.requestTermination {
            throw CatalogError.coordinatedWriteFailed
        } completion: { result in
            if case .failure = result { didFail = true }
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1)
        XCTAssertTrue(didFail)
        XCTAssertFalse(controller.isTerminationPending)
    }

    @MainActor
    func testTerminationTimeoutCannotHangIndefinitely() async {
        let controller = ApplicationTerminationController(timeout: .milliseconds(20))
        let completed = expectation(description: "Termination timeout returned")
        var didFail = false

        _ = controller.requestTermination {
            try await Task.sleep(for: .seconds(30))
        } completion: { result in
            if case .failure = result { didFail = true }
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1)
        XCTAssertTrue(didFail)
        XCTAssertFalse(controller.isTerminationPending)
    }

    private func projectSource(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }
}
