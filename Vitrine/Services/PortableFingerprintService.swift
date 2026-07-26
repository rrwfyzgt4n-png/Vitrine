import CryptoKit
import Foundation

actor PortableFingerprintService {
    private let sampleSize = 65_536

    func fingerprint(for url: URL, fileSize: Int64, width: Int, height: Int) throws -> String {
        try Task.checkCancellation()
        let before = try revision(url)
        guard before.size == fileSize else { throw CatalogError.unstableSourceFile(url) }
        try Task.checkCancellation()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digestInput = Data("\(fileSize)|\(width)|\(height)|".utf8)
        if fileSize <= Int64(sampleSize * 2) {
            digestInput.append(try handle.readToEnd() ?? Data())
        } else {
            digestInput.append(try handle.read(upToCount: sampleSize) ?? Data())
            try Task.checkCancellation()
            try handle.seek(toOffset: UInt64(fileSize - Int64(sampleSize)))
            digestInput.append(try handle.read(upToCount: sampleSize) ?? Data())
        }
        try Task.checkCancellation()
        let after = try revision(url)
        guard before == after else { throw CatalogError.unstableSourceFile(url) }
        try Task.checkCancellation()
        return SHA256.hash(data: digestInput).map { String(format: "%02x", $0) }.joined()
    }

    func fullFingerprint(for url: URL) throws -> String {
        let before = try revision(url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation()
            hasher.update(data: chunk)
        }
        guard before == (try revision(url)) else { throw CatalogError.unstableSourceFile(url) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func revision(_ url: URL) throws -> FileRevision {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return FileRevision(size: Int64(values.fileSize ?? 0), modified: values.contentModificationDate)
    }

    private struct FileRevision: Equatable {
        var size: Int64
        var modified: Date?
    }
}
