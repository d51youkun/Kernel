import Foundation

@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    @Published var models: [ModelEntry] = []

    private let modelsDirectory: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models")
    }()

    private let storageURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("models.json")
    }()

    private init() {
        loadModels()
    }

    func loadModels() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ModelEntry].self, from: data) else {
            scanModelsDirectory()
            return
        }

        models = decoded
        syncWithDirectory()
    }

    func scanModelsDirectory() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: modelsDirectory,
                                                                       includingPropertiesForKeys: nil) else { return }

        let ggufFiles = files.filter { $0.pathExtension.lowercased() == "gguf" }

        for file in ggufFiles {
            let fileName = file.lastPathComponent
            if !models.contains(where: { $0.fileName == fileName }) {
                let entry = ModelEntry(displayName: fileName.replacingOccurrences(of: ".gguf", with: ""),
                                       fileName: fileName)
                models.append(entry)
            }
        }

        saveModels()
    }

    func syncWithDirectory() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: modelsDirectory,
                                                                       includingPropertiesForKeys: nil) else { return }

        let fileNames = Set(files.map { $0.lastPathComponent })
        models = models.filter { fileNames.contains($0.fileName) }

        for file in files where file.pathExtension.lowercased() == "gguf" {
            let fileName = file.lastPathComponent
            if !models.contains(where: { $0.fileName == fileName }) {
                let entry = ModelEntry(displayName: fileName.replacingOccurrences(of: ".gguf", with: ""),
                                       fileName: fileName)
                models.append(entry)
            }
        }

        saveModels()
    }

    func addModel(displayName: String, fileName: String) {
        let entry = ModelEntry(displayName: displayName, fileName: fileName)
        models.append(entry)
        saveModels()
    }

    func deleteModel(_ model: ModelEntry) {
        let fileURL = model.fileURL
        try? FileManager.default.removeItem(at: fileURL)
        models.removeAll { $0.id == model.id }
        saveModels()
    }

    func renameModel(_ model: ModelEntry, to newDisplayName: String) {
        guard let index = models.firstIndex(where: { $0.id == model.id }) else { return }
        models[index].displayName = newDisplayName
        saveModels()
    }

    private func saveModels() {
        guard let data = try? JSONEncoder().encode(models) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
