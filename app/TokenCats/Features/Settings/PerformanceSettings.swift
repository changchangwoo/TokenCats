import SwiftUI

/// 최적화: how often the room redraws, and battery saver.
struct PerformanceSettings: View {
    @AppStorage(AppSettings.Key.animationQuality) private var quality = AppSettings.Default.animationQuality
    @AppStorage(AppSettings.Key.batterySaver) private var batterySaver = AppSettings.Default.batterySaver
    @ObservedObject private var battery = BatteryStatusViewModel.shared

    private func name(_ quality: AnimationQuality) -> LocalizedStringResource {
        switch quality {
        case .smooth: return "Smooth (12 fps)"
        case .balanced: return "Balanced (8 fps)"
        case .saver: return "Saver (4 fps)"
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Animation quality", selection: $quality) {
                    ForEach(AnimationQuality.allCases, id: \.self) { Text(name($0)).tag($0.rawValue) }
                }
            } footer: {
                Text("How many times a second the home cat room redraws. Lower uses less power.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Battery saver", isOn: $batterySaver)
                LabeledContent("Active now") {
                    if AppSettings.power.blinks {
                        Text(name(AppSettings.power.quality))
                    } else {
                        Text("\(name(AppSettings.power.quality)) · blinking paused" as LocalizedStringResource)
                    }
                }
            } footer: {
                Text("On battery or in Low Power Mode, drops to Saver and stops the closed notch's blinking.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Performance")
    }
}
