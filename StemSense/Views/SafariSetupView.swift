import SwiftUI

struct SafariSetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("One-time Safari setup")
                        .font(.largeTitle.bold())
                    Text("After this, YouTube in Safari responds directly to your AirPods stems.")
                        .foregroundStyle(.secondary)
                }

                SetupStep(number: 1, text: "Open Settings, then Apps → Safari → Extensions.")
                SetupStep(number: 2, text: "Tap StemSense and switch on Allow Extension.")
                SetupStep(number: 3, text: "Set youtube.com access to Allow.")

                VStack(alignment: .leading, spacing: 9) {
                    Label("Double-press", systemImage: "airpodspro").font(.headline)
                    Text("Skip forward 10 seconds")
                    Divider()
                    Label("Triple-press", systemImage: "airpodspro").font(.headline)
                    Text("Skip backward 10 seconds")
                }
                .padding()
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))

                Spacer()

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.86, green: 1.0, blue: 0.37))
                .foregroundStyle(.black)
            }
            .padding(22)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SetupStep: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(Color(red: 0.86, green: 1.0, blue: 0.37), in: Circle())
            Text(text)
                .font(.body.weight(.medium))
                .padding(.top, 5)
        }
    }
}
