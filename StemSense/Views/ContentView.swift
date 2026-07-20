import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: PlayerController
    @FocusState private var linkFocused: Bool

    var body: some View {
        ZStack {
            StemPalette.background.ignoresSafeArea()
            AmbientBackground()

            ScrollView {
                VStack(spacing: 24) {
                    HeaderView()
                    PlayerCard()
                    LinkComposer(linkFocused: $linkFocused)
                    RouteExplainer()
                    PrivacyNote()
                }
                .frame(maxWidth: 920)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            if let notice = player.notice {
                VStack {
                    Spacer()
                    NoticeToast(text: notice)
                        .onTapGesture { player.notice = nil }
                        .padding(.bottom, 18)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: notice)
            }
        }
        .sheet(isPresented: $player.showSafariSetup) {
            SafariSetupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $player.showStemLab) {
            StemSenseLabView(engine: player.stemSense)
                .presentationDragIndicator(.visible)
        }
    }
}

private struct HeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(StemPalette.acid)
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(StemPalette.background)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 1) {
                Text("STEMSENSE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(-0.8)
                Text("Your AirPods are the scrubber now.")
                    .font(.subheadline)
                    .foregroundStyle(StemPalette.secondary)
            }
            Spacer()
            Capsule()
                .fill(StemPalette.acid.opacity(0.12))
                .overlay {
                    Label("10 sec", systemImage: "airpodspro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StemPalette.acid)
                        .padding(.horizontal, 11)
                }
                .frame(width: 88, height: 32)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlayerCard: View {
    @EnvironmentObject private var player: PlayerController

    var body: some View {
        VStack(spacing: 0) {
            YouTubeWebView(webView: player.webView)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Text(time(player.snapshot.currentTime))
                        .monospacedDigit()
                    Slider(
                        value: Binding(
                            get: { player.snapshot.currentTime },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.snapshot.duration, 1)
                    )
                    .tint(StemPalette.acid)
                    .accessibilityLabel("Video position")
                    Text("−\(time(max(player.snapshot.duration - player.snapshot.currentTime, 0)))")
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(StemPalette.secondary)

                HStack(spacing: 24) {
                    transportButton(icon: "gobackward.10", label: "Back 10 seconds") {
                        player.seek(by: -10)
                    }
                    Button {
                        player.togglePlayback()
                    } label: {
                        Image(systemName: player.snapshot.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(StemPalette.background)
                            .frame(width: 54, height: 54)
                            .background(StemPalette.acid, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.snapshot.isPlaying ? "Pause" : "Play")

                    transportButton(icon: "goforward.10", label: "Forward 10 seconds") {
                        player.seek(by: 10)
                    }
                }

                HStack(spacing: 8) {
                    GesturePill(count: 2, text: "+10")
                    Text("Double-press forward")
                    Circle().frame(width: 3, height: 3)
                    GesturePill(count: 3, text: "−10")
                    Text("Triple-press back")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(StemPalette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
            .padding(16)
            .background(StemPalette.panel)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 28, y: 16)
    }

    private func transportButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func time(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "0:00" }
        let total = max(0, Int(value.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

private struct GesturePill: View {
    let count: Int
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule().fill(StemPalette.acid).frame(width: 3, height: 9)
            }
            Text(text).foregroundStyle(StemPalette.acid)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(StemPalette.acid.opacity(0.09), in: Capsule())
    }
}

private struct LinkComposer: View {
    @EnvironmentObject private var player: PlayerController
    let linkFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("PLAY A VIDEO")
                .font(.caption.weight(.black))
                .tracking(1.4)
                .foregroundStyle(StemPalette.secondary)

            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(linkFocused.wrappedValue ? StemPalette.acid : StemPalette.secondary)
                TextField("Paste a YouTube link", text: $player.input)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .focused(linkFocused)
                    .submitLabel(.go)
                    .onSubmit(player.submitInput)
                Button("Play", action: player.submitInput)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(StemPalette.background)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(StemPalette.acid, in: Capsule())
                    .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(linkFocused.wrappedValue ? StemPalette.acid.opacity(0.65) : Color.white.opacity(0.08))
            }

            Button(action: player.pasteAndPlay) {
                Label("Paste clipboard and play", systemImage: "doc.on.clipboard")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RouteExplainer: View {
    @EnvironmentObject private var player: PlayerController

    var body: some View {
        VStack(spacing: 10) {
            RouteCard(
                eyebrow: "FASTEST",
                title: "Keep watching in Safari",
                detail: "Enable the included extension once. Every youtube.com video gets AirPods skipping automatically.",
                icon: "safari.fill",
                actionTitle: "Set up"
            ) {
                player.showSafariSetup = true
            }

            RouteCard(
                eyebrow: "FOCUS MODE",
                title: "Play inside StemSense",
                detail: "Paste any standard YouTube URL above. Lock-screen and AirPods commands stay mapped to ten seconds.",
                icon: "rectangle.inset.filled.and.person.filled",
                actionTitle: nil,
                action: nil
            )

            RouteCard(
                eyebrow: "EXPERIMENTAL · REAL SIGNALS",
                title: "Split Stem Lab",
                detail: "Calibrate a personalized left/right motion fingerprint, keep one stem as volume, and translate the other into accelerated scrubbing.",
                icon: "waveform.path.ecg.rectangle",
                actionTitle: "Open lab"
            ) {
                player.showStemLab = true
            }
        }
    }
}

private struct RouteCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(StemPalette.acid)
                .frame(width: 44, height: 44)
                .background(StemPalette.acid.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow).font(.system(size: 9, weight: .black)).tracking(1.2).foregroundStyle(StemPalette.acid)
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(StemPalette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
                    .tint(StemPalette.acid)
            }
        }
        .padding(15)
        .background(StemPalette.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06))
        }
    }
}

private struct PrivacyNote: View {
    var body: some View {
        Label("StemSense stores no account, history, or analytics.", systemImage: "hand.raised.fill")
            .font(.caption)
            .foregroundStyle(StemPalette.secondary)
            .padding(.top, 2)
    }
}

private struct NoticeToast: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.13)) }
            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
    }
}

private struct AmbientBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(StemPalette.acid.opacity(0.11))
                .frame(width: min(proxy.size.width, 520), height: min(proxy.size.width, 520))
                .blur(radius: 100)
                .offset(x: proxy.size.width * 0.52, y: -180)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private enum StemPalette {
    static let background = Color(red: 0.027, green: 0.032, blue: 0.037)
    static let panel = Color(red: 0.065, green: 0.073, blue: 0.078)
    static let acid = Color(red: 0.86, green: 1.0, blue: 0.37)
    static let secondary = Color(red: 0.62, green: 0.65, blue: 0.63)
}
