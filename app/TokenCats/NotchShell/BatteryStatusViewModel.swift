// Written for TokenCats; it replaces boring.notch's battery manager and lives here because it is window-shell state.
import Combine
import Foundation
import IOKit.ps

/// Battery state for the power-saver policy (Settings › 최적화). Nothing is shown; it only answers
/// "running on battery?" and "low power mode?". A Mac without a battery reports `maxCapacity == 0`.
@MainActor
final class BatteryStatusViewModel: ObservableObject {
    static let shared = BatteryStatusViewModel()

    @Published private(set) var isPluggedIn = true
    @Published private(set) var maxCapacity: Float = 0
    @Published private(set) var isInLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var runLoopSource: CFRunLoopSource?
    private var lowPowerObserver: Any?

    private init() {
        refresh()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<BatteryStatusViewModel>.fromOpaque(context).takeUnretainedValue().refresh()
            }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, Unmanaged.passUnretained(self).toOpaque())?
            .takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        lowPowerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isInLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
    }

    private func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let description = IOPSGetPowerSourceDescription(info, first)?.takeUnretainedValue() as? [String: Any]
        else {
            apply(capacity: 0, pluggedIn: true)
            return
        }
        apply(capacity: Float(description[kIOPSMaxCapacityKey] as? Int ?? 0),
              pluggedIn: (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue)
    }

    /// Assigns only what changed, so a battery-level tick does not redraw the room.
    private func apply(capacity: Float, pluggedIn: Bool) {
        if maxCapacity != capacity { maxCapacity = capacity }
        if isPluggedIn != pluggedIn { isPluggedIn = pluggedIn }
    }
}
