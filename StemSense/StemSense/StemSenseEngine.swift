import AVFAudio
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class StemSenseEngine: ObservableObject {
    enum Phase: Equatable {
        case idle
        case calibrating(StemSide)
        case evaluating
        case ready
        case armed
        case failed(String)
    }

    struct Event: Identifiable, Equatable {
        let id = UUID()
        let time = Date()
        let text: String
        let isSuccess: Bool
    }

    static let calibrationTarget = 12
    static let minimumAccuracy = 0.85
    static let minimumConfidence = 0.12

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var leftSamples = 0
    @Published private(set) var rightSamples = 0
    @Published private(set) var validationAccuracy: Double = 0
    @Published private(set) var lastPrediction: StemPrediction?
    @Published private(set) var motionAvailable = false
    @Published private(set) var contactCaptureRunning = false
    @Published private(set) var events: [Event] = []
    @Published var scrubSide: StemSide = .right {
        didSet { persistPreferences() }
    }
    @Published var contactAssist = false {
        didSet {
            guard contactAssist != oldValue else { return }
            resetCalibration(reason: "Signal recipe changed. Recalibration required.")
            persistPreferences()
            if contactAssist {
                startContactCapture()
            } else {
                contact.stop()
                contactCaptureRunning = false
            }
        }
    }

    var onScrub: ((TimeInterval) -> Void)?
    var volumeSide: StemSide { scrubSide.opposite }
    var isOperational: Bool { phase == .armed }

    private let motion = HeadphoneMotionCapture()
    private let contact = ContactAudioCapture()
    private var volumeObservation: NSKeyValueObservation?
    private weak var systemVolumeSlider: UISlider?
    private var leftVectors: [StemFeatureVector] = []
    private var rightVectors: [StemFeatureVector] = []
    private var model: StemClassifierModel?
    private var ignoredRestoration: (value: Float, until: TimeInterval)?
    private var lastObservedVolume = AVAudioSession.sharedInstance().outputVolume

    init() {
        loadPreferences()
        loadModel()
        motion.availabilityChanged = { [weak self] available in
            Task { @MainActor in
                self?.motionAvailable = available
            }
        }
        motionAvailable = motion.isAvailable
    }

    func attachSystemVolumeSlider(_ slider: UISlider) {
        systemVolumeSlider = slider
    }

    func start() {
        motion.start()
        motionAvailable = motion.isAvailable
        observeSystemVolume()
        if contactAssist {
            startContactCapture()
        }
        if let model, model.validationAccuracy >= Self.minimumAccuracy {
            validationAccuracy = model.validationAccuracy
            phase = .ready
        } else if phase == .idle {
            appendEvent("Sensors active. Calibrate each stem.", success: true)
        }
    }

    func stop() {
        phase = .idle
        volumeObservation = nil
        motion.stop()
        contact.stop()
        contactCaptureRunning = false
    }

    func beginCalibration(for side: StemSide) {
        guard motionAvailable else {
            phase = .failed("Headphone Motion is unavailable. Connect compatible AirPods and try again.")
            return
        }
        if side == .left { leftVectors.removeAll() } else { rightVectors.removeAll() }
        updateCounts()
        model = nil
        validationAccuracy = 0
        phase = .calibrating(side)
        appendEvent("Calibrating \(side.title): perform \(Self.calibrationTarget) natural swipes.", success: true)
    }

    func arm() {
        guard let model, model.validationAccuracy >= Self.minimumAccuracy else {
            phase = .failed("Calibration has not crossed the 85% held-out accuracy gate.")
            return
        }
        phase = .armed
        appendEvent("Split Stem armed: \(volumeSide.title) volume · \(scrubSide.title) scrub.", success: true)
    }

    func disarm() {
        phase = model == nil ? .idle : .ready
        appendEvent("Split Stem disarmed.", success: true)
    }

    func resetCalibration(reason: String? = nil) {
        leftVectors.removeAll()
        rightVectors.removeAll()
        model = nil
        validationAccuracy = 0
        lastPrediction = nil
        updateCounts()
        UserDefaults.standard.removeObject(forKey: Storage.model)
        phase = .idle
        if let reason { appendEvent(reason, success: false) }
    }

    private func observeSystemVolume() {
        guard volumeObservation == nil else { return }
        let session = AVAudioSession.sharedInstance()
        lastObservedVolume = session.outputVolume
        volumeObservation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            guard let oldValue = change.oldValue, let newValue = change.newValue else { return }
            Task { @MainActor in
                self?.volumeDidChange(from: oldValue, to: newValue)
            }
        }
    }

    private func volumeDidChange(from oldValue: Float, to newValue: Float) {
        let now = ProcessInfo.processInfo.systemUptime
        if let ignoredRestoration,
           now <= ignoredRestoration.until,
           abs(newValue - ignoredRestoration.value) < 0.015 {
            self.ignoredRestoration = nil
            lastObservedVolume = newValue
            return
        }

        let baseline = abs(oldValue - lastObservedVolume) < 0.02 ? oldValue : lastObservedVolume
        let delta = Double(newValue - baseline)
        lastObservedVolume = newValue
        guard abs(delta) >= 0.005 else { return }

        let phaseAtEvent = phase
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(240))
            self?.processSwipe(
                timestamp: now,
                previousVolume: baseline,
                newVolume: newValue,
                delta: delta,
                phaseAtEvent: phaseAtEvent
            )
        }
    }

    private func processSwipe(
        timestamp: TimeInterval,
        previousVolume: Float,
        newVolume: Float,
        delta: Double,
        phaseAtEvent: Phase
    ) {
        let motionSamples = motion.buffer.samples(from: timestamp - 0.48, through: timestamp + 0.20)
        let audioSamples = contact.buffer.samples(from: timestamp - 0.48, through: timestamp + 0.20)
        let vector = StemFeatureExtractor.makeVector(
            motion: motionSamples,
            audio: audioSamples,
            volumeDelta: delta,
            includeAudio: contactAssist
        )

        switch phaseAtEvent {
        case .calibrating(let side):
            guard motionSamples.count >= 3 else {
                appendEvent("Swipe ignored: insufficient motion samples.", success: false)
                return
            }
            addCalibration(vector, for: side)
        case .armed:
            applyRuntimeDecision(vector, previousVolume: previousVolume, newVolume: newVolume, delta: delta)
        default:
            break
        }
    }

    private func addCalibration(_ vector: StemFeatureVector, for side: StemSide) {
        if side == .left {
            guard leftVectors.count < Self.calibrationTarget else { return }
            leftVectors.append(vector)
        } else {
            guard rightVectors.count < Self.calibrationTarget else { return }
            rightVectors.append(vector)
        }
        updateCounts()
        appendEvent("\(side.title) sample \(side == .left ? leftSamples : rightSamples)/\(Self.calibrationTarget)", success: true)

        if (side == .left ? leftSamples : rightSamples) >= Self.calibrationTarget {
            phase = .idle
            if leftSamples >= Self.calibrationTarget && rightSamples >= Self.calibrationTarget {
                trainAndEvaluate()
            }
        }
    }

    private func trainAndEvaluate() {
        phase = .evaluating
        guard let trained = StemClassifierModel.train(left: leftVectors, right: rightVectors) else {
            phase = .failed("The classifier could not be trained from these samples.")
            return
        }
        model = trained
        validationAccuracy = trained.validationAccuracy

        if trained.validationAccuracy >= Self.minimumAccuracy {
            phase = .ready
            saveModel(trained)
            appendEvent("Held-out accuracy \(Int(trained.validationAccuracy * 100))%. Split Stem passed.", success: true)
        } else {
            phase = .failed("Held-out accuracy was \(Int(trained.validationAccuracy * 100))%. Recalibrate or enable Contact Assist.")
            appendEvent("Classifier rejected at \(Int(trained.validationAccuracy * 100))% accuracy.", success: false)
        }
    }

    private func applyRuntimeDecision(
        _ vector: StemFeatureVector,
        previousVolume: Float,
        newVolume: Float,
        delta: Double
    ) {
        guard let prediction = model?.predict(vector) else { return }
        lastPrediction = prediction

        guard prediction.confidence >= Self.minimumConfidence else {
            appendEvent("Uncertain swipe (\(Int(prediction.confidence * 100))% margin); volume kept.", success: false)
            return
        }

        if prediction.side == scrubSide {
            restoreSystemVolume(to: previousVolume)
            let energy = StemFeatureExtractor.gestureEnergy(in: vector)
            let notchCount = max(abs(delta) / 0.0625, 1)
            let acceleration = min(max(energy * 1.6, 0), 2.5)
            let seconds = min(45, max(3, (8 + acceleration * 8) * notchCount))
            let signedSeconds = delta > 0 ? seconds : -seconds
            onScrub?(signedSeconds)
            appendEvent(
                "\(prediction.side.title) scrub \(signedSeconds > 0 ? "+" : "")\(Int(signedSeconds))s · \(Int(prediction.confidence * 100))% margin",
                success: true
            )
        } else {
            lastObservedVolume = newVolume
            appendEvent(
                "\(prediction.side.title) volume kept · \(Int(prediction.confidence * 100))% margin",
                success: true
            )
        }
    }

    private func restoreSystemVolume(to value: Float) {
        guard let slider = systemVolumeSlider else {
            appendEvent("Scrub detected, but the system-volume bridge is unavailable.", success: false)
            return
        }
        ignoredRestoration = (value, ProcessInfo.processInfo.systemUptime + 0.8)
        lastObservedVolume = value
        slider.setValue(value, animated: false)
        slider.sendActions(for: .valueChanged)
    }

    private func startContactCapture() {
        contact.start { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.contactCaptureRunning = true
                self.appendEvent("Contact Assist is listening locally; no audio is stored.", success: true)
            case .failure(let error):
                self.contactCaptureRunning = false
                self.contactAssist = false
                self.appendEvent(error.localizedDescription, success: false)
            }
        }
    }

    private func updateCounts() {
        leftSamples = leftVectors.count
        rightSamples = rightVectors.count
    }

    private func appendEvent(_ text: String, success: Bool) {
        events.insert(Event(text: text, isSuccess: success), at: 0)
        if events.count > 12 { events.removeLast(events.count - 12) }
    }

    private func saveModel(_ model: StemClassifierModel) {
        if let data = try? JSONEncoder().encode(model) {
            UserDefaults.standard.set(data, forKey: Storage.model)
        }
    }

    private func loadModel() {
        guard let data = UserDefaults.standard.data(forKey: Storage.model),
              let stored = try? JSONDecoder().decode(StemClassifierModel.self, from: data) else { return }
        model = stored
        validationAccuracy = stored.validationAccuracy
        phase = stored.validationAccuracy >= Self.minimumAccuracy ? .ready : .idle
    }

    private func persistPreferences() {
        UserDefaults.standard.set(scrubSide.rawValue, forKey: Storage.scrubSide)
        UserDefaults.standard.set(contactAssist, forKey: Storage.contactAssist)
    }

    private func loadPreferences() {
        if let rawValue = UserDefaults.standard.string(forKey: Storage.scrubSide),
           let storedSide = StemSide(rawValue: rawValue) {
            scrubSide = storedSide
        }
        contactAssist = UserDefaults.standard.bool(forKey: Storage.contactAssist)
    }

    private enum Storage {
        static let model = "StemSense.classifier.v1"
        static let scrubSide = "StemSense.scrubSide"
        static let contactAssist = "StemSense.contactAssist"
    }
}
