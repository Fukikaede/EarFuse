import Foundation
import Meter
import XCTest

final class MeterCalculatorTests: XCTestCase {
    func testMeterCalculatorReturnsValidPeakAndRMS() {
        let calculator = MeterCalculator()
        let samples: [Float] = [0, 0.5, -0.5, 0.25]

        let snapshot = calculator.calculate(samples: samples, timestamp: Date())

        XCTAssertGreaterThan(snapshot.peakDBFS, -7)
        XCTAssertLessThan(snapshot.peakDBFS, -5)
        XCTAssertGreaterThan(snapshot.rmsDBFS, -11)
        XCTAssertLessThan(snapshot.rmsDBFS, -8)
    }
}
