import AVFAudio
import CoreMotion
import Foundation

struct TimedSignalSample: Sendable {
    let timestamp: TimeInterval
    let channels: [Double]
}

final class SignalRingBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [TimedSignalSample] = []
    private let retention: TimeInterval

    init(retention: TimeInterval = 3) {
        self.retention = retention
    }

    func append(_ sample: TimedSignalSample) {
        lock.lock()
        samples.append(sample)
        let cutoff = sample.timestamp - retention
        if let firstValid = samples.firstIndex(where: { $0.timestamp >= cutoff }), firstValid > 0 {
            samples.removeFirst(firstValid)
        }
        lock.unlock()
    }

    func samples(from start: TimeInterval, through end: TimeInterval) -> [TimedSignalSample] {
        lock.lock()
        let result = samples.filter { $0.timestamp >= start && $0.timestamp <= end }
        lock.unlock()
        return result
    }

    func reset() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}

final class HeadphoneMotionCapture: NSObject, CMHeadphoneMotionManagerDelegate {
    let buffer = SignalRingBuffer()
    var availabilityChanged: (@Sendable (Bool) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "StemSense.HeadphoneMotion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    override init() {
        super.init()
        manager.delegate = self
    }

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else {
            availabilityChanged?(manager.isDeviceMotionAvailable)
            return
        }
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard error == nil, let motion else { return }
            self?.buffer.append(
                TimedSignalSample(
                    timestamp: motion.timestamp,
                    channels: [
                        motion.rotationRate.x,
                        motion.rotationRate.y,
                        motion.rotationRate.z,
                        motion.userAcceleration.x,
                        motion.userAcceleration.y,
                        motion.userAcceleration.z,
                        motion.gravity.x,
                        motion.gravity.y,
                        motion.gravity.z
                    ]
                )
            )
        }
        availabilityChanged?(true)
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        buffer.reset()
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        availabilityChanged?(manager.isDeviceMotionAvailable)
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        availabilityChanged?(false)
    }
}

final class ContactAudioCapture: @unchecked Sendable {
    let buffer = SignalRingBuffer()

    private let engine = AVAudioEngine()
    private(set) var isRunning = false

    @MainActor
    func start(completion: @escaping (Result<Void, Error>) -> Void) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else {
                Task { @MainActor in completion(.failure(ContactCaptureError.permissionDenied)) }
                return
            }
            Task { @MainActor in
                do {
                    try self?.startEngine()
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    @MainActor
    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        buffer.reset()
    }

    @MainActor
    private func startEngine() throws {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        var options: AVAudioSession.CategoryOptions = [.allowBluetoothHFP]
        if #available(iOS 26.0, *) {
            options.insert(.bluetoothHighQualityRecording)
        }
        try session.setCategory(.playAndRecord, mode: .default, options: options)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] pcm, _ in
            guard let self, let channelData = pcm.floatChannelData else { return }
            let frameCount = Int(pcm.frameLength)
            let channelCount = Int(pcm.format.channelCount)
            guard frameCount > 0, channelCount > 0 else { return }

            var squareSum = 0.0
            var peak = 0.0
            var differenceSum = 0.0
            var previous = 0.0
            var sampleCount = 0

            for channel in 0..<channelCount {
                let data = channelData[channel]
                previous = Double(data[0])
                for frame in 0..<frameCount {
                    let value = Double(data[frame])
                    squareSum += value * value
                    peak = max(peak, abs(value))
                    if frame > 0 {
                        let difference = value - previous
                        differenceSum += difference * difference
                    }
                    previous = value
                    sampleCount += 1
                }
            }

            let denominator = Double(max(sampleCount, 1))
            self.buffer.append(
                TimedSignalSample(
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    channels: [sqrt(squareSum / denominator), peak, sqrt(differenceSum / denominator)]
                )
            )
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }
}

enum ContactCaptureError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Microphone permission is required for contact-signal assist."
    }
}

enum StemFeatureExtractor {
    static let motionChannelCount = 9
    static let audioChannelCount = 3

    static func makeVector(
        motion: [TimedSignalSample],
        audio: [TimedSignalSample],
        volumeDelta: Double,
        includeAudio: Bool
    ) -> StemFeatureVector {
        var values = statistics(for: motion, channelCount: motionChannelCount)
        if includeAudio {
            values.append(contentsOf: statistics(for: audio, channelCount: audioChannelCount))
        }
        values.append(volumeDelta)
        values.append(abs(volumeDelta))
        return StemFeatureVector(values: values)
    }

    static func gestureEnergy(in vector: StemFeatureVector) -> Double {
        guard vector.values.count >= 4 else { return 0 }
        let motionPeaks = stride(from: 2, to: min(36, vector.values.count), by: 4).map { vector.values[$0] }
        return motionPeaks.reduce(0, +) / Double(max(motionPeaks.count, 1))
    }

    private static func statistics(
        for samples: [TimedSignalSample],
        channelCount: Int
    ) -> [Double] {
        guard !samples.isEmpty else { return Array(repeating: 0, count: channelCount * 4) }
        return (0..<channelCount).flatMap { channel -> [Double] in
            let channelValues = samples.compactMap { sample in
                sample.channels.indices.contains(channel) ? sample.channels[channel] : nil
            }
            guard !channelValues.isEmpty else { return [0, 0, 0, 0] }
            let mean = channelValues.reduce(0, +) / Double(channelValues.count)
            let meanAbsolute = channelValues.reduce(0) { $0 + abs($1) } / Double(channelValues.count)
            let peak = channelValues.map(abs).max() ?? 0
            let variance = channelValues.reduce(0) { partial, value in
                let delta = value - mean
                return partial + delta * delta
            } / Double(channelValues.count)
            return [mean, meanAbsolute, peak, sqrt(variance)]
        }
    }
}
