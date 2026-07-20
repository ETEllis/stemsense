import AVFAudio
import MediaPlayer

@MainActor
final class RemoteCommandController {
    private var registrations: [(MPRemoteCommand, Any)] = []
    private weak var player: PlayerController?
    private var lastNowPlayingSecond = -1

    func connect(to player: PlayerController) {
        guard self.player == nil else { return }
        self.player = player
        registerCommands()
    }

    func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            player?.notice = "AirPods control could not claim the audio session."
        }
    }

    func updateNowPlaying(_ snapshot: PlayerSnapshot, force: Bool = false) {
        let second = Int(snapshot.currentTime)
        guard force || second != lastNowPlayingSecond else { return }
        lastNowPlayingSecond = second

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyArtist: "StemSense · YouTube",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        if snapshot.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = snapshot.duration
        }
        if let videoID = snapshot.videoID {
            info[MPNowPlayingInfoPropertyExternalContentIdentifier] = videoID
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = snapshot.isPlaying ? .playing : .paused
    }

    private func registerCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.preferredIntervals = [10]

        register(center.nextTrackCommand) { [weak self] _ in
            self?.player?.seek(by: 10)
            return .success
        }
        register(center.previousTrackCommand) { [weak self] _ in
            self?.player?.seek(by: -10)
            return .success
        }
        register(center.skipForwardCommand) { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            self?.player?.seek(by: interval)
            return .success
        }
        register(center.skipBackwardCommand) { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 10
            self?.player?.seek(by: -interval)
            return .success
        }
        register(center.playCommand) { [weak self] _ in
            self?.player?.play()
            return .success
        }
        register(center.pauseCommand) { [weak self] _ in
            self?.player?.pause()
            return .success
        }
        register(center.togglePlayPauseCommand) { [weak self] _ in
            self?.player?.togglePlayback()
            return .success
        }
        register(center.changePlaybackPositionCommand) { [weak self] event in
            guard let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                return .commandFailed
            }
            self?.player?.seek(to: position)
            return .success
        }
    }

    private func register(
        _ command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let token = command.addTarget(handler: handler)
        registrations.append((command, token))
    }

    deinit {
        for (command, token) in registrations {
            command.removeTarget(token)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
