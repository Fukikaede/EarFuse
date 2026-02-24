import Audio
import SwiftUI

public struct MeterHistoryChart: View {
    let points: [MeterHistoryPoint]
    private let maxDisplayPoints = 100

    public init(points: [MeterHistoryPoint]) {
        self.points = points
    }

    public var body: some View {
        let displayPoints = sampledPoints(from: points, maxPoints: maxDisplayPoints)
        GeometryReader { geo in
            ZStack {
                thresholdBand(yMin: -14, yMax: 0, color: .red.opacity(0.12), in: geo.size)
                thresholdBand(yMin: -20, yMax: -14, color: .orange.opacity(0.12), in: geo.size)
                rmsPath(points: displayPoints, in: geo.size)
                    .stroke(Color.orange.opacity(0.95), lineWidth: 2.0)
                peakPath(points: displayPoints, in: geo.size)
                    .stroke(Color.red.opacity(0.35), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 64)
    }

    private func thresholdBand(yMin: Float, yMax: Float, color: Color, in size: CGSize) -> some View {
        let top = yPosition(db: yMax, height: size.height)
        let bottom = yPosition(db: yMin, height: size.height)
        return Rectangle()
            .fill(color)
            .frame(height: max(0, bottom - top))
            .offset(y: top)
    }

    private func rmsPath(points: [MeterHistoryPoint], in size: CGSize) -> Path {
        linePath(points: points, in: size) { $0.displayRMSDBFS }
    }

    private func peakPath(points: [MeterHistoryPoint], in size: CGSize) -> Path {
        linePath(points: points, in: size) { $0.peakDBFS }
    }

    private func linePath(points: [MeterHistoryPoint], in size: CGSize, value: (MeterHistoryPoint) -> Float) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let minDB: Float = -60
        let maxDB: Float = 0
        let firstTime = points.first?.timestamp ?? Date()
        let lastTime = points.last?.timestamp ?? firstTime
        let timeSpan = max(lastTime.timeIntervalSince(firstTime), 0.001)

        for (index, point) in points.enumerated() {
            let x = size.width * CGFloat(point.timestamp.timeIntervalSince(firstTime) / timeSpan)
            let clamped = min(max(value(point), minDB), maxDB)
            let y = yPosition(db: clamped, height: size.height)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func sampledPoints(from points: [MeterHistoryPoint], maxPoints: Int) -> [MeterHistoryPoint] {
        guard points.count > maxPoints, maxPoints > 1 else { return points }

        var result: [MeterHistoryPoint] = []
        result.reserveCapacity(maxPoints)

        let lastIndex = points.count - 1
        let step = Double(lastIndex) / Double(maxPoints - 1)

        for i in 0..<maxPoints {
            let index = Int((Double(i) * step).rounded())
            result.append(points[min(index, lastIndex)])
        }

        return result
    }

    private func yPosition(db: Float, height: CGFloat) -> CGFloat {
        let minDB: Float = -60
        let maxDB: Float = 0
        let normalized = (db - minDB) / (maxDB - minDB)
        return height * CGFloat(1 - normalized)
    }
}
