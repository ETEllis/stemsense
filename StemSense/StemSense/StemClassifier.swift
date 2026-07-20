import Foundation

enum StemSide: String, Codable, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var opposite: StemSide { self == .left ? .right : .left }
    var title: String { rawValue.capitalized }
}

struct StemFeatureVector: Codable, Equatable {
    let values: [Double]
}

struct StemPrediction: Equatable {
    let side: StemSide
    let confidence: Double
    let leftDistance: Double
    let rightDistance: Double
}

struct StemClassifierModel: Codable, Equatable {
    let means: [Double]
    let scales: [Double]
    let leftCentroid: [Double]
    let rightCentroid: [Double]
    let validationAccuracy: Double
    let featureCount: Int

    func predict(_ vector: StemFeatureVector) -> StemPrediction? {
        guard vector.values.count == featureCount else { return nil }
        let normalized = Self.normalize(vector.values, means: means, scales: scales)
        let left = Self.distance(normalized, leftCentroid)
        let right = Self.distance(normalized, rightCentroid)
        let side: StemSide = left <= right ? .left : .right
        let denominator = max(left + right, 0.000_001)
        let confidence = min(max(abs(left - right) / denominator, 0), 1)
        return StemPrediction(side: side, confidence: confidence, leftDistance: left, rightDistance: right)
    }

    static func train(
        left: [StemFeatureVector],
        right: [StemFeatureVector],
        minimumPerSide: Int = 8
    ) -> StemClassifierModel? {
        guard left.count >= minimumPerSide,
              right.count >= minimumPerSide,
              let featureCount = left.first?.values.count,
              featureCount > 0,
              (left + right).allSatisfy({ $0.values.count == featureCount }) else { return nil }

        let all = left + right
        let means = columnMeans(all.map(\.values), count: featureCount)
        let scales = columnScales(all.map(\.values), means: means, count: featureCount)
        let normalizedLeft = left.map { normalize($0.values, means: means, scales: scales) }
        let normalizedRight = right.map { normalize($0.values, means: means, scales: scales) }
        let leftCentroid = columnMeans(normalizedLeft, count: featureCount)
        let rightCentroid = columnMeans(normalizedRight, count: featureCount)
        let accuracy = leaveOneOutAccuracy(left: left, right: right)

        return StemClassifierModel(
            means: means,
            scales: scales,
            leftCentroid: leftCentroid,
            rightCentroid: rightCentroid,
            validationAccuracy: accuracy,
            featureCount: featureCount
        )
    }

    private static func leaveOneOutAccuracy(
        left: [StemFeatureVector],
        right: [StemFeatureVector]
    ) -> Double {
        var correct = 0
        var total = 0

        for index in left.indices {
            var training = left
            let heldOut = training.remove(at: index)
            if let model = trainWithoutValidation(left: training, right: right),
               model.predict(heldOut)?.side == .left { correct += 1 }
            total += 1
        }
        for index in right.indices {
            var training = right
            let heldOut = training.remove(at: index)
            if let model = trainWithoutValidation(left: left, right: training),
               model.predict(heldOut)?.side == .right { correct += 1 }
            total += 1
        }
        return total == 0 ? 0 : Double(correct) / Double(total)
    }

    private static func trainWithoutValidation(
        left: [StemFeatureVector],
        right: [StemFeatureVector]
    ) -> StemClassifierModel? {
        guard let featureCount = left.first?.values.count,
              !right.isEmpty,
              featureCount > 0 else { return nil }
        let all = left + right
        let means = columnMeans(all.map(\.values), count: featureCount)
        let scales = columnScales(all.map(\.values), means: means, count: featureCount)
        return StemClassifierModel(
            means: means,
            scales: scales,
            leftCentroid: columnMeans(left.map { normalize($0.values, means: means, scales: scales) }, count: featureCount),
            rightCentroid: columnMeans(right.map { normalize($0.values, means: means, scales: scales) }, count: featureCount),
            validationAccuracy: 0,
            featureCount: featureCount
        )
    }

    private static func columnMeans(_ rows: [[Double]], count: Int) -> [Double] {
        guard !rows.isEmpty else { return Array(repeating: 0, count: count) }
        return (0..<count).map { column in
            rows.reduce(0) { $0 + $1[column] } / Double(rows.count)
        }
    }

    private static func columnScales(_ rows: [[Double]], means: [Double], count: Int) -> [Double] {
        guard !rows.isEmpty else { return Array(repeating: 1, count: count) }
        return (0..<count).map { column in
            let variance = rows.reduce(0) { partial, row in
                let delta = row[column] - means[column]
                return partial + delta * delta
            } / Double(rows.count)
            return max(sqrt(variance), 0.000_001)
        }
    }

    private static func normalize(_ values: [Double], means: [Double], scales: [Double]) -> [Double] {
        zip(zip(values, means), scales).map { pair, scale in
            (pair.0 - pair.1) / scale
        }
    }

    private static func distance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        sqrt(zip(lhs, rhs).reduce(0) { partial, pair in
            let delta = pair.0 - pair.1
            return partial + delta * delta
        })
    }
}
