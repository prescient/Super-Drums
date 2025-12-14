import XCTest
@testable import SuperDrums

final class SongArrangementTests: XCTestCase {

    // MARK: - SongArrangementEntry

    func test_songArrangementEntry_defaultRepeatCount_isOne() {
        let entry = SongArrangementEntry(patternIndex: 0)
        XCTAssertEqual(entry.repeatCount, 1)
    }

    func test_songArrangementEntry_clampsRepeatCount_minimum() {
        let entry = SongArrangementEntry(patternIndex: 0, repeatCount: 0)
        XCTAssertEqual(entry.repeatCount, 1)
    }

    func test_songArrangementEntry_clampsRepeatCount_maximum() {
        let entry = SongArrangementEntry(patternIndex: 0, repeatCount: 999)
        XCTAssertEqual(entry.repeatCount, 99)
    }

    func test_songArrangementEntry_duplicate_createsNewID() {
        let original = SongArrangementEntry(patternIndex: 0, repeatCount: 4)
        let copy = original.duplicate()

        XCTAssertNotEqual(original.id, copy.id)
        XCTAssertEqual(original.patternIndex, copy.patternIndex)
        XCTAssertEqual(original.repeatCount, copy.repeatCount)
    }

    // MARK: - Project Song Arrangement

    func test_project_addToSong_appendsEntry() {
        var project = Project()
        project.addToSong(patternIndex: 0)

        XCTAssertEqual(project.songArrangement.count, 1)
        XCTAssertEqual(project.songArrangement[0].patternIndex, 0)
    }

    func test_project_addToSong_withRepeatCount() {
        var project = Project()
        project.addToSong(patternIndex: 0, repeatCount: 4)

        XCTAssertEqual(project.songArrangement[0].repeatCount, 4)
    }

    func test_project_clearSongArrangement_removesAll() {
        var project = Project()
        project.addToSong(patternIndex: 0)
        project.addToSong(patternIndex: 0)
        project.clearSongArrangement()

        XCTAssertTrue(project.songArrangement.isEmpty)
    }

    func test_project_songDurationInLoops_calculatesTotal() {
        var project = Project()
        project.addToSong(patternIndex: 0, repeatCount: 2)
        project.addToSong(patternIndex: 0, repeatCount: 3)
        project.addToSong(patternIndex: 0, repeatCount: 1)

        XCTAssertEqual(project.songDurationInLoops, 6)
    }

    func test_project_deletePattern_updatesSongArrangement() {
        var project = Project()
        project.addPattern() // Pattern 2
        project.addToSong(patternIndex: 0)
        project.addToSong(patternIndex: 1)

        project.deletePattern(at: 0)

        // Entry referencing pattern 0 should be removed
        // Entry referencing pattern 1 should now reference pattern 0
        XCTAssertEqual(project.songArrangement.count, 1)
        XCTAssertEqual(project.songArrangement[0].patternIndex, 0)
    }
}
