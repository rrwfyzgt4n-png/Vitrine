import AppKit
import XCTest
@testable import Vitrine

@MainActor
final class CatalogPanelServiceTests: XCTestCase {
    func testCoverFolderPanelConfigurationWithoutPresentingIt() {
        let panel = CatalogPanelService.makeCoverFolderPanel()

        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(panel.canChooseFiles)
        XCTAssertTrue(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertFalse(panel.canCreateDirectories)
    }

    func testCatalogOpenPanelConfigurationWithoutPresentingIt() {
        let panel = CatalogPanelService.makeCatalogOpenPanel()

        XCTAssertFalse(panel.isVisible)
        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertFalse(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
        XCTAssertTrue(panel.allowedContentTypes.contains { $0.preferredFilenameExtension == "md" })
    }
}
