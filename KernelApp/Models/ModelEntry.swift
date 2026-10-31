import Foundation

struct ModelEntry: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var displayName: String
    var fileName: String
    var createdAt: Date = Date()

    var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models")
            .appendingPathComponent(fileName)
    }

    var fileSizeBytes: Int64? {
        guard let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attr[.size] as? Int64 else { return nil }
        return size
    }

    var fileSizeString: String {
        guard let bytes = fileSizeBytes else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
