import SwiftUI

struct StemSenseLabView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var engine: StemSenseEngine

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    assignmentCard
                    signalCard
                    calibrationCard
                    runtimeCard
                    eventLog
                }
                .padding(18)
                .padding(.bottom, 28)
            }
            .background(Color(red: 0.027, green: 0.032, blue: 0.037).ignoresSafeArea())
            .navigationTitle("Split Stem Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { engine.start() }
        .onDisappear {
            if !engine.isOperational { engine.stop() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("STEMSENSE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(acid)
                Spacer()
                statusPill
            }
            Text("We infer the hand Apple won’t identify.")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-1)
            Text("Each system-volume event is fused with the surrounding AirPods motion signature. The classifier must prove ≥85% held-out accuracy before scrubbing can arm.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [acid.opacity(0.17), Color.white.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private var statusPill: some View {
        Text(phaseTitle)
            .font(.caption2.weight(.black))
            .foregroundStyle(engine.isOperational ? .black : acid)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(engine.isOperational ? acid : acid.opacity(0.1), in: Capsule())
    }

    private var assignmentCard: some View {
        labCard(title: "1 · ASSIGN THE STEMS", icon: "airpodspro") {
            Picker("Scrub stem", selection: $engine.scrubSide) {
                ForEach(StemSide.allCases) { side in
                    Text("\(side.title) scrubs").tag(side)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                role(side: engine.volumeSide, name: "VOLUME", icon: "speaker.wave.2.fill")
                Image(systemName: "arrow.left.and.right").foregroundStyle(.tertiary)
                role(side: engine.scrubSide, name: "SCRUB", icon: "timeline.selection")
            }
        }
    }

    private var signalCard: some View {
        labCard(title: "2 · BUILD THE VIRTUAL GRADIENT", icon: "gyroscope") {
            signalRow(
                title: "AirPods motion",
                detail: engine.motionAvailable ? "Rotation + acceleration online" : "Compatible AirPods not detected",
                active: engine.motionAvailable
            )

            Toggle(isOn: $engine.contactAssist) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Contact Assist").font(.subheadline.weight(.semibold))
                    Text("Adds local microphone energy to the classifier")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(acid)

            if engine.contactAssist {
                Label(
                    "For maximum asymmetry, set Settings → AirPods → Microphone to Always \(engine.scrubSide.title). Audio is reduced to energy features in memory and never stored.",
                    systemImage: "ear.and.waveform"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("System volume bridge")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                SystemVolumeBridge { slider in
                    engine.attachSystemVolumeSlider(slider)
                }
                .frame(height: 32)
            }
        }
    }

    private var calibrationCard: some View {
        labCard(title: "3 · CALIBRATE AND FALSIFY", icon: "scope") {
            Text("Do 12 natural swipes on each side, alternating up and down. Keep your head relaxed. Repeating this under slightly different posture makes the model harder to fool.")
                .font(.caption)
                .foregroundStyle(.secondary)

            calibrationRow(side: .left, count: engine.leftSamples)
            calibrationRow(side: .right, count: engine.rightSamples)

            if engine.validationAccuracy > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Held-out accuracy").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(engine.validationAccuracy, format: .percent.precision(.fractionLength(0)))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(engine.validationAccuracy >= StemSenseEngine.minimumAccuracy ? acid : .orange)
                    }
                    ProgressView(value: engine.validationAccuracy)
                        .tint(engine.validationAccuracy >= StemSenseEngine.minimumAccuracy ? acid : .orange)
                }
            }

            if case .failed(let message) = engine.phase {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button("Reset calibration", role: .destructive) {
                engine.resetCalibration()
            }
            .font(.caption.weight(.semibold))
        }
    }

    private var runtimeCard: some View {
        labCard(title: "4 · ARM THE TRANSLATOR", icon: "point.3.connected.trianglepath.dotted") {
            if engine.isOperational {
                HStack(spacing: 12) {
                    Circle().fill(acid).frame(width: 10, height: 10).shadow(color: acid, radius: 7)
                    VStack(alignment: .leading) {
                        Text("Split Stem is live").font(.headline)
                        Text("\(engine.volumeSide.title) keeps volume · \(engine.scrubSide.title) becomes timeline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Button("Disarm", action: engine.disarm)
                    .buttonStyle(.bordered)
            } else {
                Button(action: engine.arm) {
                    Label("Arm Split Stem", systemImage: "bolt.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(acid)
                .foregroundStyle(.black)
                .disabled(engine.validationAccuracy < StemSenseEngine.minimumAccuracy)
            }

            Text("Low-confidence events fail safe as ordinary volume. Scrub events restore the prior volume and seek the StemSense player using inferred gesture energy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("LIVE INFERENCE")
                .font(.caption.weight(.black))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            if engine.events.isEmpty {
                Text("No signals yet.").font(.caption).foregroundStyle(.tertiary)
            } else {
                ForEach(engine.events.prefix(7)) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(event.isSuccess ? acid : Color.orange)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(event.text).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func calibrationRow(side: StemSide, count: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(side.title) stem").font(.subheadline.weight(.semibold))
                    Text("\(count)/\(StemSenseEngine.calibrationTarget) captured")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(calibrationButtonTitle(for: side)) {
                    engine.beginCalibration(for: side)
                }
                .buttonStyle(.bordered)
                .tint(acid)
                .disabled(isCalibrating)
            }
            ProgressView(value: Double(count), total: Double(StemSenseEngine.calibrationTarget))
                .tint(acid)
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private func calibrationButtonTitle(for side: StemSide) -> String {
        if case .calibrating(side) = engine.phase { return "Listening…" }
        return "Calibrate"
    }

    private var isCalibrating: Bool {
        if case .calibrating = engine.phase { return true }
        return false
    }

    private func role(side: StemSide, name: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(acid)
            Text(side.title).font(.headline)
            Text(name).font(.system(size: 9, weight: .black)).tracking(1).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    private func signalRow(title: String, detail: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Circle().fill(active ? acid : Color.orange).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func labCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.black))
                .tracking(1.1)
                .foregroundStyle(acid)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Color(red: 0.065, green: 0.073, blue: 0.078), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.07))
        }
    }

    private var phaseTitle: String {
        switch engine.phase {
        case .idle: "IDLE"
        case .calibrating(let side): "\(side.rawValue.uppercased()) INPUT"
        case .evaluating: "EVALUATING"
        case .ready: "GATE PASSED"
        case .armed: "ARMED"
        case .failed: "REJECTED"
        }
    }

    private var acid: Color { Color(red: 0.86, green: 1.0, blue: 0.37) }
}
