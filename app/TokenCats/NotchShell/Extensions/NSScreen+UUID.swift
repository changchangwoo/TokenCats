// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import AppKit
import CoreGraphics

extension NSScreen {
    /// Returns a persistent UUID for this display
    var displayUUID: String? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            return nil
        }
        let uuidString = CFUUIDCreateString(nil, uuid.takeRetainedValue()) as String
        return uuidString
    }
    
    /// The display the notch starts on before the user picks one: the built-in screen (where a MacBook's notch is)
    /// even when the menu bar lives on an external monitor, otherwise the main one.
    @MainActor static var firstChoiceUUID: String? {
        FirstDisplay.pick(screens.compactMap { screen in
            guard let uuid = screen.displayUUID,
                  let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            else { return nil }
            return FirstDisplay.Candidate(uuid: uuid, isBuiltIn: CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0,
                                          isMain: screen == NSScreen.main)
        })
    }

    /// Find a screen by its UUID
    @MainActor static func screen(withUUID uuid: String) -> NSScreen? {
        return NSScreenUUIDCache.shared.screen(forUUID: uuid)
    }
    
    /// Get UUID to NSScreen mapping for all screens
    @MainActor static var screensByUUID: [String: NSScreen] {
        return NSScreenUUIDCache.shared.allScreens
    }
}

/// Cache for UUID to NSScreen mappings to avoid repeated lookups
@MainActor
final class NSScreenUUIDCache {
    static let shared = NSScreenUUIDCache()
    
    private var cache: [String: NSScreen] = [:]
    private var observer: Any?
    
    private init() {
        rebuildCache()
        setupObserver()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildCache()
        }
    }
    
    private func rebuildCache() {
        var newCache: [String: NSScreen] = [:]
        
        for screen in NSScreen.screens {
            if let uuid = screen.displayUUID {
                newCache[uuid] = screen
            }
        }
        
        cache = newCache
    }
    
    func screen(forUUID uuid: String) -> NSScreen? {
        return cache[uuid]
    }
    
    var allScreens: [String: NSScreen] {
        return cache
    }
}
