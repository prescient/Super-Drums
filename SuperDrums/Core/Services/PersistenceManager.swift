import Foundation

/// Handles saving and loading projects and drum kits to/from disk.
actor PersistenceManager {
    static let shared = PersistenceManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Directory URLs

    /// Documents directory for user files
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Projects directory
    private var projectsDirectory: URL {
        documentsDirectory.appendingPathComponent("Projects", isDirectory: true)
    }

    /// Drum kits directory
    private var kitsDirectory: URL {
        documentsDirectory.appendingPathComponent("Kits", isDirectory: true)
    }

    // MARK: - Directory Setup

    /// Ensures required directories exist
    func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: projectsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: kitsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Project Operations

    /// Saves a project to disk
    func saveProject(_ project: Project) throws {
        try ensureDirectoriesExist()
        let fileName = sanitizeFileName(project.name) + ".superdrums"
        let fileURL = projectsDirectory.appendingPathComponent(fileName)
        let data = try encoder.encode(project)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads a project from disk by name
    func loadProject(named name: String) throws -> Project {
        let fileName = sanitizeFileName(name) + ".superdrums"
        let fileURL = projectsDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Project.self, from: data)
    }

    /// Loads a project from a specific URL
    func loadProject(from url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        return try decoder.decode(Project.self, from: data)
    }

    /// Lists all saved projects
    func listProjects() throws -> [ProjectMetadata] {
        try ensureDirectoriesExist()
        let contents = try fileManager.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )

        return contents
            .filter { $0.pathExtension == "superdrums" }
            .compactMap { url -> ProjectMetadata? in
                guard let data = try? Data(contentsOf: url),
                      let project = try? decoder.decode(Project.self, from: data) else {
                    return nil
                }
                return ProjectMetadata(
                    id: project.id,
                    name: project.name,
                    createdAt: project.createdAt,
                    modifiedAt: project.modifiedAt,
                    patternCount: project.patterns.count,
                    fileURL: url
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Deletes a project from disk
    func deleteProject(named name: String) throws {
        let fileName = sanitizeFileName(name) + ".superdrums"
        let fileURL = projectsDirectory.appendingPathComponent(fileName)
        try fileManager.removeItem(at: fileURL)
    }

    /// Deletes a project by URL
    func deleteProject(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    // MARK: - Drum Kit Operations

    /// Saves a drum kit to disk
    func saveKit(_ kit: DrumKit) throws {
        try ensureDirectoriesExist()
        let fileName = sanitizeFileName(kit.name) + ".superdrumskit"
        let fileURL = kitsDirectory.appendingPathComponent(fileName)
        let data = try encoder.encode(kit)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads a drum kit from disk by name
    func loadKit(named name: String) throws -> DrumKit {
        let fileName = sanitizeFileName(name) + ".superdrumskit"
        let fileURL = kitsDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(DrumKit.self, from: data)
    }

    /// Loads a drum kit from a specific URL
    func loadKit(from url: URL) throws -> DrumKit {
        let data = try Data(contentsOf: url)
        return try decoder.decode(DrumKit.self, from: data)
    }

    /// Lists all saved drum kits
    func listKits() throws -> [KitMetadata] {
        try ensureDirectoriesExist()
        let contents = try fileManager.contentsOfDirectory(
            at: kitsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )

        return contents
            .filter { $0.pathExtension == "superdrumskit" }
            .compactMap { url -> KitMetadata? in
                guard let data = try? Data(contentsOf: url),
                      let kit = try? decoder.decode(DrumKit.self, from: data) else {
                    return nil
                }
                return KitMetadata(
                    id: kit.id,
                    name: kit.name,
                    createdAt: kit.createdAt,
                    modifiedAt: kit.modifiedAt,
                    fileURL: url
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Deletes a drum kit from disk
    func deleteKit(named name: String) throws {
        let fileName = sanitizeFileName(name) + ".superdrumskit"
        let fileURL = kitsDirectory.appendingPathComponent(fileName)
        try fileManager.removeItem(at: fileURL)
    }

    /// Deletes a drum kit by URL
    func deleteKit(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    // MARK: - Utilities

    /// Sanitizes a name for use as a filename
    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name
            .components(separatedBy: invalidCharacters)
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .isEmpty ? "Untitled" : name
                .components(separatedBy: invalidCharacters)
                .joined()
                .trimmingCharacters(in: .whitespaces)
    }

    /// Checks if a project with the given name exists
    func projectExists(named name: String) -> Bool {
        let fileName = sanitizeFileName(name) + ".superdrums"
        let fileURL = projectsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Checks if a kit with the given name exists
    func kitExists(named name: String) -> Bool {
        let fileName = sanitizeFileName(name) + ".superdrumskit"
        let fileURL = kitsDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
}

// MARK: - Metadata Types

/// Lightweight metadata for project list display
struct ProjectMetadata: Identifiable, Equatable {
    let id: UUID
    let name: String
    let createdAt: Date
    let modifiedAt: Date
    let patternCount: Int
    let fileURL: URL
}

/// Lightweight metadata for kit list display
struct KitMetadata: Identifiable, Equatable {
    let id: UUID
    let name: String
    let createdAt: Date
    let modifiedAt: Date
    let fileURL: URL
}
