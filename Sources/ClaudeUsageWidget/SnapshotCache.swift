import Foundation
import UsageCore

enum SnapshotCache {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeUsageWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-snapshot.json")
    }

    static func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(UsageSnapshot.self, from: data)
    }

    static func save(_ snapshot: UsageSnapshot) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        guard let data = try? enc.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
