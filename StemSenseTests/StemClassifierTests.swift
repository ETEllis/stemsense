import XCTest
@testable import StemSense

final class StemClassifierTests: XCTestCase {
    func testLearnsSeparableLeftAndRightSignals() throws {
        let left = (0..<12).map { index in
            StemFeatureVector(values: [-2.0 + Double(index) * 0.02, -1.4, 0.25])
        }
        let right = (0..<12).map { index in
            StemFeatureVector(values: [2.0 + Double(index) * 0.02, 1.4, 0.28])
        }

        let model = try XCTUnwrap(StemClassifierModel.train(left: left, right: right))
        XCTAssertGreaterThanOrEqual(model.validationAccuracy, 0.95)
        XCTAssertEqual(model.predict(StemFeatureVector(values: [-1.8, -1.2, 0.24]))?.side, .left)
        XCTAssertEqual(model.predict(StemFeatureVector(values: [2.2, 1.3, 0.29]))?.side, .right)
    }

    func testRejectsTooFewCalibrationSamples() {
        let samples = Array(repeating: StemFeatureVector(values: [1, 2]), count: 7)
        XCTAssertNil(StemClassifierModel.train(left: samples, right: samples))
    }

    func testPredictionRejectsWrongFeatureShape() throws {
        let left = Array(repeating: StemFeatureVector(values: [-1, 0]), count: 8)
        let right = Array(repeating: StemFeatureVector(values: [1, 0]), count: 8)
        let model = try XCTUnwrap(StemClassifierModel.train(left: left, right: right))
        XCTAssertNil(model.predict(StemFeatureVector(values: [1, 2, 3])))
    }
}
