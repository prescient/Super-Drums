import XCTest
@testable import SuperDrums

final class TrackRandomizationTests: XCTestCase {

    // MARK: - Euclidean Pattern Generation

    func test_euclideanPattern_4hitsOver16Steps_generatesCorrectPattern() {
        let pattern = TrackRandomizationSettings.euclideanPattern(hits: 4, steps: 16)

        // Should have exactly 4 hits
        XCTAssertEqual(pattern.filter { $0 }.count, 4)

        // Hits should be evenly distributed: indices 0, 4, 8, 12
        XCTAssertTrue(pattern[0])
        XCTAssertTrue(pattern[4])
        XCTAssertTrue(pattern[8])
        XCTAssertTrue(pattern[12])
    }

    func test_euclideanPattern_3hitsOver8Steps() {
        let pattern = TrackRandomizationSettings.euclideanPattern(hits: 3, steps: 8)

        XCTAssertEqual(pattern.filter { $0 }.count, 3)
        XCTAssertEqual(pattern.count, 8)
    }

    func test_euclideanPattern_5hitsOver16Steps() {
        let pattern = TrackRandomizationSettings.euclideanPattern(hits: 5, steps: 16)

        XCTAssertEqual(pattern.filter { $0 }.count, 5)
        XCTAssertEqual(pattern.count, 16)
    }

    func test_euclideanPattern_0hits_returnsAllFalse() {
        let pattern = TrackRandomizationSettings.euclideanPattern(hits: 0, steps: 8)

        XCTAssertEqual(pattern.filter { $0 }.count, 0)
        XCTAssertEqual(pattern.count, 8)
    }

    func test_euclideanPattern_hitsEqualSteps_returnsAllTrue() {
        let pattern = TrackRandomizationSettings.euclideanPattern(hits: 8, steps: 8)

        XCTAssertEqual(pattern.filter { $0 }.count, 8)
        XCTAssertTrue(pattern.allSatisfy { $0 })
    }

    func test_euclideanPattern_1hit_placeAtStart() {
        let pattern = TrackRandomizationSettings.euclideanPattern(hits: 1, steps: 16)

        XCTAssertEqual(pattern.filter { $0 }.count, 1)
        XCTAssertTrue(pattern[0])
    }

    // MARK: - Randomization Presets

    func test_sparsePreset_hasLowDensity() {
        let settings = TrackRandomizationSettings.sparse
        XCTAssertLessThan(settings.density, 0.3)
    }

    func test_densePreset_hasHighDensity() {
        let settings = TrackRandomizationSettings.dense
        XCTAssertGreaterThan(settings.density, 0.5)
    }

    func test_euclidean4Preset_uses4Hits() {
        let settings = TrackRandomizationSettings.euclidean4
        XCTAssertTrue(settings.useEuclidean)
        XCTAssertEqual(settings.euclideanHits, 4)
    }

    // MARK: - Parameter Toggle Defaults

    func test_defaultSettings_randomizesStepsAndVelocity() {
        let settings = TrackRandomizationSettings()
        XCTAssertTrue(settings.randomizeSteps)
        XCTAssertTrue(settings.randomizeVelocity)
        XCTAssertFalse(settings.randomizeProbability)
        XCTAssertFalse(settings.randomizeRetriggers)
    }

    func test_velocityOnlyPreset_keepsPattern() {
        let settings = TrackRandomizationSettings.velocityOnly
        XCTAssertFalse(settings.randomizeSteps)
        XCTAssertTrue(settings.randomizeVelocity)
    }
}
