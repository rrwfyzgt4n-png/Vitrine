import XCTest
@testable import Vitrine

final class PortableFingerprintServiceTests: XCTestCase {
    func testCancelledPartialFingerprintStopsBeforeReading() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data(repeating: 0x5A, count: 2_000_000)
        try data.write(to: url)
        let service = PortableFingerprintService()
        let task = Task {
            try await service.fingerprint(
                for: url,
                fileSize: Int64(data.count),
                width: 1_000,
                height: 1_500
            )
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("A cancelled partial fingerprint unexpectedly completed.")
        } catch is CancellationError {
            // Expected.
        }
    }
}
