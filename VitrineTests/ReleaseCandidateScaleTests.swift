import CoreGraphics
import CryptoKit
import Darwin
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Vitrine

final class ReleaseCandidateScaleTests: XCTestCase {
    func testSyntheticLibrariesAtReleaseCandidateScale() async throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["VITRINE_RUN_RELEASE_SCALE"] != "1" &&
                !FileManager.default.fileExists(atPath: releaseSentinelURL.path),
            "Run through script/release_candidate.sh to execute large-library verification."
        )
        let counts = requestedCounts
        let maximumCount = try XCTUnwrap(counts.max())
        let root = FileManager.default.temporaryDirectory
            .appending(path: "Vitrine-Release-\(UUID().uuidString)", directoryHint: .isDirectory)
        let covers = root.appending(path: "Covers", directoryHint: .isDirectory)
        let seed = root.appending(path: "Seed.jpg")
        try FileManager.default.createDirectory(at: covers, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeJPEG(to: seed, width: 1_200, height: 1_800)

        var createdCount = 0
        for count in counts {
            try addCovers(from: createdCount, through: count, seed: seed, folder: covers)
            createdCount = count
            let sourceHashBefore = try sourceManifest(in: covers)
            let fixedDate = Date(timeIntervalSince1970: 1_750_000_000)
            let snapshot = syntheticCatalog(count: count, date: fixedDate)

            let renderStart = CFAbsoluteTimeGetCurrent()
            let markdown = try CatalogMarkdownWriter().render(snapshot)
            let parseStart = CFAbsoluteTimeGetCurrent()
            let parsed = try CatalogMarkdownParser().parse(markdown).snapshot
            let parseEnd = CFAbsoluteTimeGetCurrent()

            let scanStart = CFAbsoluteTimeGetCurrent()
            let scan = try await CatalogScanner().scan(folderURL: covers)
            let scanEnd = CFAbsoluteTimeGetCurrent()
            let sourceHashAfter = try sourceManifest(in: covers)

            let gridStart = CFAbsoluteTimeGetCurrent()
            let visibleCount = await MainActor.run { () -> Int in
                let store = CatalogStore()
                store.catalog = parsed
                store.sortOption = .titleAscending
                return store.visibleItems.count
            }
            let gridEnd = CFAbsoluteTimeGetCurrent()

            let cacheService = ThumbnailService()
            let firstSource = try XCTUnwrap(scan.sources.first)
            let thumbnailMissStart = CFAbsoluteTimeGetCurrent()
            _ = try await cacheService.thumbnail(
                sourceFolderURL: covers,
                source: firstSource,
                maximumPixelSize: 336
            )
            let thumbnailHitStart = CFAbsoluteTimeGetCurrent()
            _ = try await cacheService.thumbnail(
                sourceFolderURL: covers,
                source: firstSource,
                maximumPixelSize: 336
            )
            let thumbnailEnd = CFAbsoluteTimeGetCurrent()
            let cacheStatistics = await cacheService.statistics()

            var cancellationMilliseconds: Double?
            if count == maximumCount {
                let cancellationStart = CFAbsoluteTimeGetCurrent()
                let task = Task { try await CatalogScanner().scan(folderURL: covers) }
                await Task.yield()
                task.cancel()
                do {
                    _ = try await task.value
                    XCTFail("A cancelled refresh unexpectedly completed.")
                } catch is CancellationError {
                    cancellationMilliseconds = milliseconds(since: cancellationStart)
                } catch {
                    XCTFail("Cancelled refresh failed with an unexpected error: \(error)")
                }
            }

            let metric: [String: Any] = [
                "books": count,
                "catalog_bytes": markdown.lengthOfBytes(using: .utf8),
                "render_ms": milliseconds(from: renderStart, to: parseStart),
                "launch_to_grid_parse_ms": milliseconds(from: parseStart, to: parseEnd),
                "refresh_ms": milliseconds(from: scanStart, to: scanEnd),
                "grid_model_ms": milliseconds(from: gridStart, to: gridEnd),
                "thumbnail_miss_ms": milliseconds(from: thumbnailMissStart, to: thumbnailHitStart),
                "thumbnail_hit_ms": milliseconds(from: thumbnailHitStart, to: thumbnailEnd),
                "thumbnail_cache_hits": cacheStatistics.hits,
                "thumbnail_cache_misses": cacheStatistics.misses,
                "peak_resident_bytes": peakResidentBytes(),
                "cancellation_ms": cancellationMilliseconds as Any,
                "source_sha256_before": sourceHashBefore,
                "source_sha256_after": sourceHashAfter,
            ]
            let data = try JSONSerialization.data(withJSONObject: metric, options: [.sortedKeys])
            print("VITRINE_RELEASE_METRIC \(String(decoding: data, as: UTF8.self))")

            XCTAssertEqual(parsed.items.count, count)
            XCTAssertEqual(scan.sources.count, count)
            XCTAssertTrue(scan.completedEnumeration)
            XCTAssertEqual(visibleCount, count)
            XCTAssertEqual(sourceHashAfter, sourceHashBefore, "A source cover changed during verification.")
            XCTAssertEqual(cacheStatistics.hits, 1)
            XCTAssertEqual(cacheStatistics.misses, 1)
            XCTAssertLessThan(parseEnd - parseStart, 20, "Catalog parsing exceeded the release-candidate ceiling.")
            XCTAssertLessThan(scanEnd - scanStart, 180, "Cover refresh exceeded the release-candidate ceiling.")
            XCTAssertLessThan(gridEnd - gridStart, 5, "Grid model preparation exceeded the release-candidate ceiling.")
            if let cancellationMilliseconds {
                XCTAssertLessThan(cancellationMilliseconds, 2_000, "Refresh cancellation was not responsive.")
            }
        }
    }

    private var requestedCounts: [Int] {
        let raw = ProcessInfo.processInfo.environment["VITRINE_RELEASE_SCALE_COUNTS"] ?? "1000,2500,5000"
        return raw.split(separator: ",").compactMap { Int($0) }.filter { $0 > 0 }.sorted()
    }

    private var releaseSentinelURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: ".build/RunReleaseScale")
    }

    private func syntheticCatalog(count: Int, date: Date) -> CatalogSnapshot {
        let items = (0..<count).map { number in
            CatalogItem(
                id: deterministicUUID(number),
                source: SourceFileMetadata(relativePath: String(format: "Cover-%05d.jpg", number)),
                bibliography: BibliographicMetadata(
                    title: "Synthetic Book \(number)",
                    authors: ["Author \(number % 250)"],
                    publisher: "Release Candidate Press",
                    publicationDate: "\(1800 + number % 226)",
                    pageCount: 100 + number % 900,
                    subjects: ["Scale verification"],
                    metadataSource: .manual,
                    metadataConfirmedByUser: true
                ),
                dateAdded: date,
                dateModified: date
            )
        }
        return CatalogSnapshot(
            name: "Synthetic \(count)",
            createdAt: date,
            updatedAt: date,
            sourceFolderName: "Covers",
            items: items
        )
    }

    private func deterministicUUID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", number))!
    }

    private func addCovers(from start: Int, through end: Int, seed: URL, folder: URL) throws {
        guard end > start else { return }
        for number in start..<end {
            let destination = folder.appending(path: String(format: "Cover-%05d.jpg", number))
            try FileManager.default.copyItem(at: seed, to: destination)
        }
    }

    private func sourceManifest(in folder: URL) throws -> String {
        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        var manifest = SHA256()
        for file in files {
            manifest.update(data: Data(file.lastPathComponent.utf8))
            manifest.update(data: Data(SHA256.hash(data: try Data(contentsOf: file))))
        }
        return manifest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func writeJPEG(to url: URL, width: Int, height: Int) throws {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.18, green: 0.34, blue: 0.61, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func peakResidentBytes() -> UInt64 {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        return UInt64(max(0, usage.ru_maxrss))
    }

    private func milliseconds(since start: CFAbsoluteTime) -> Double {
        milliseconds(from: start, to: CFAbsoluteTimeGetCurrent())
    }

    private func milliseconds(from start: CFAbsoluteTime, to end: CFAbsoluteTime) -> Double {
        (((end - start) * 1_000) * 1_000).rounded() / 1_000
    }
}
