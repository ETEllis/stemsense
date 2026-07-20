import Foundation
import UIKit
import WebKit

@MainActor
final class PlayerController: NSObject, ObservableObject {
    @Published private(set) var snapshot = PlayerSnapshot()
    @Published var input = ""
    @Published var notice: String?
    @Published var showSafariSetup = false
    @Published var showStemLab = false

    let webView: WKWebView
    let stemSense = StemSenseEngine()
    private let remoteCommands = RemoteCommandController()
    private var shellReady = false
    private var pendingVideoID: String?
    private lazy var messageProxy = WeakScriptMessageHandler(target: self)

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.video]
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        configuration.userContentController.add(messageProxy, name: "stemsense")
        remoteCommands.connect(to: self)
        stemSense.onScrub = { [weak self] seconds in
            self?.seek(by: seconds)
        }
        loadPlayerShell()
    }

    func submitInput() {
        guard let videoID = YouTubeURLParser.videoID(from: input) else {
            notice = "That doesn’t look like a YouTube video link."
            return
        }
        load(videoID: videoID)
    }

    func pasteAndPlay() {
        guard let value = UIPasteboard.general.string else {
            notice = "There isn’t a link on the clipboard yet."
            return
        }
        input = value
        submitInput()
    }

    func open(_ url: URL) {
        guard let videoID = YouTubeURLParser.videoID(from: url) else {
            notice = "StemSense couldn’t find a YouTube video in that link."
            return
        }
        input = "https://youtu.be/\(videoID)"
        load(videoID: videoID)
    }

    func load(videoID: String) {
        pendingVideoID = videoID
        snapshot = PlayerSnapshot(videoID: videoID)
        notice = nil
        guard shellReady else { return }
        evaluate("StemSense.load(\(Self.javaScriptString(videoID)))")
    }

    func seek(by interval: TimeInterval) {
        let destination = max(0, min(snapshot.duration, snapshot.currentTime + interval))
        seek(to: destination)
        notice = interval > 0 ? "+\(Int(interval)) seconds" : "\(Int(interval)) seconds"
    }

    func seek(to time: TimeInterval) {
        evaluate("StemSense.seekTo(\(max(0, time)))")
        snapshot.currentTime = max(0, min(snapshot.duration, time))
        remoteCommands.updateNowPlaying(snapshot, force: true)
    }

    func play() {
        if !stemSense.contactCaptureRunning {
            remoteCommands.activateAudioSession()
        }
        evaluate("StemSense.play()")
    }

    func pause() {
        evaluate("StemSense.pause()")
    }

    func togglePlayback() {
        snapshot.isPlaying ? pause() : play()
    }

    private func loadPlayerShell() {
        guard let url = Bundle.main.url(forResource: "PlayerShell", withExtension: "html"),
              let html = try? String(contentsOf: url, encoding: .utf8) else {
            notice = "The player could not be loaded."
            return
        }
        webView.loadHTMLString(html, baseURL: URL(string: "https://stemsense.app")!)
    }

    private func evaluate(_ script: String) {
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if error != nil {
                Task { @MainActor in
                    self?.notice = "The video player is still getting ready."
                }
            }
        }
    }

    private static func javaScriptString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let encoded = String(data: data, encoding: .utf8) else { return "\"\"" }
        return encoded
    }

    fileprivate func receive(_ body: Any) {
        guard let message = body as? [String: Any],
              let event = message["event"] as? String else { return }

        switch event {
        case "shellReady":
            shellReady = true
            if let videoID = pendingVideoID {
                evaluate("StemSense.load(\(Self.javaScriptString(videoID)))")
            }
        case "ready":
            snapshot.isReady = true
            if !stemSense.contactCaptureRunning { remoteCommands.activateAudioSession() }
            remoteCommands.updateNowPlaying(snapshot, force: true)
        case "state":
            let state = message["state"] as? Int ?? -1
            snapshot.isPlaying = state == 1
            if snapshot.isPlaying && !stemSense.contactCaptureRunning {
                remoteCommands.activateAudioSession()
            }
            remoteCommands.updateNowPlaying(snapshot, force: true)
        case "progress":
            snapshot.currentTime = message["currentTime"] as? Double ?? snapshot.currentTime
            snapshot.duration = message["duration"] as? Double ?? snapshot.duration
            remoteCommands.updateNowPlaying(snapshot)
        case "metadata":
            if let title = message["title"] as? String, !title.isEmpty {
                snapshot.title = title
                remoteCommands.updateNowPlaying(snapshot, force: true)
            }
        case "error":
            notice = "YouTube couldn’t play this video here. Try the Safari route."
        default:
            break
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: PlayerController?

    init(target: PlayerController) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task { @MainActor [weak self] in
            self?.target?.receive(message.body)
        }
    }
}
