import SwiftUI

/// "…" whose three dots light up in turn, like a typing indicator, while a number is still being read from the
/// logs. It takes the surrounding font, so it sits on the same baseline as the number that replaces it. Still
/// when Reduce Motion or the battery saver is on.
struct LoadingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion || !AppSettings.power.blinks {
            Text(verbatim: "…")
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        Text(verbatim: ".").opacity(Self.opacity(time: time, dot: index))
                    }
                }
            }
            .accessibilityLabel(Text("Loading"))
        }
    }

    /// Each dot brightens for a moment, a beat after the one before it; one full wave every 1.2 seconds.
    private static func opacity(time: TimeInterval, dot: Int) -> Double {
        let phase = (time / 1.2 - Double(dot) * 0.2).truncatingRemainder(dividingBy: 1)
        let wave = max(0, sin(phase * 2 * .pi))
        return 0.25 + 0.75 * wave
    }
}

/// A number that shows `LoadingDots` until it arrives, then fades in; later changes roll digit by digit.
struct LoadingValue: View {
    let text: String?

    var body: some View {
        Group {
            if let text {
                Text(text).contentTransition(.numericText())
            } else {
                LoadingDots()
            }
        }
        .transition(.opacity)
        .animation(.smooth(duration: 0.35), value: text)
    }
}
