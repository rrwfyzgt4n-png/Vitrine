import CoreServices
import Darwin
import Foundation

actor FinderCommentReader {
    private let attribute = "com.apple.metadata:kMDItemFinderComment"
    private let maximumBytes = 1_048_576

    func comment(for url: URL) -> String? {
        if let direct = readExtendedAttribute(url: url) { return direct }
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL),
              let value = MDItemCopyAttribute(item, kMDItemFinderComment) else { return nil }
        if let text = value as? String { return normalized(text) }
        if let values = value as? [String] { return normalized(values.joined(separator: "\n")) }
        return nil
    }

    private func readExtendedAttribute(url: URL) -> String? {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return nil }
            let size = getxattr(path, attribute, nil, 0, 0, 0)
            guard size > 0, size <= maximumBytes else { return nil }
            var data = Data(count: size)
            let read = data.withUnsafeMutableBytes { buffer in
                getxattr(path, attribute, buffer.baseAddress, size, 0, 0)
            }
            guard read > 0 else { return nil }
            data.count = read
            guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
            if let text = plist as? String { return normalized(text) }
            if let values = plist as? [String] { return normalized(values.joined(separator: "\n")) }
            return nil
        }
    }

    private func normalized(_ value: String) -> String? {
        let result = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
