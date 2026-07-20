import SwiftUI

@main
struct StemSenseApp: App {
    @StateObject private var player = PlayerController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    player.open(url)
                }
        }
    }
}
