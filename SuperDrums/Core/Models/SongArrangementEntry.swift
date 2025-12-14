import Foundation

/// Represents a single entry in the song arrangement.
/// Each entry references a pattern and how many times it should repeat.
struct SongArrangementEntry: Identifiable, Codable, Equatable {
    let id: UUID

    /// Index of the pattern in the project's patterns array
    var patternIndex: Int

    /// Number of times this pattern repeats before moving to the next entry
    var repeatCount: Int

    // MARK: - Initialization

    init(id: UUID = UUID(), patternIndex: Int, repeatCount: Int = 1) {
        self.id = id
        self.patternIndex = patternIndex
        self.repeatCount = max(1, min(99, repeatCount))
    }
}

// MARK: - Convenience

extension SongArrangementEntry {
    /// Creates a copy with a new ID
    func duplicate() -> SongArrangementEntry {
        SongArrangementEntry(
            patternIndex: patternIndex,
            repeatCount: repeatCount
        )
    }
}
