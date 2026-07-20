import MediaPlayer
import SwiftUI

struct SystemVolumeBridge: UIViewRepresentable {
    let onSliderReady: (UISlider) -> Void

    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        DispatchQueue.main.async {
            if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
                onSliderReady(slider)
            }
        }
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
