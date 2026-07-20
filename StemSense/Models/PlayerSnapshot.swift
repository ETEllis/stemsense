import Foundation

struct PlayerSnapshot: Equatable {
    var videoID: String?
    var title = "YouTube"
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying = false
    var isReady = false

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
}
