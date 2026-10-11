import SwiftUI

/// Reads the editable Home display file when the Home opens; no notch or agent settings live here.
@MainActor
final class UIDisplayModel: ObservableObject {
    static let shared = UIDisplayModel()

    @Published private(set) var settings: UIDisplaySettings
    private let file = DataFiles.live.uiDisplay

    private init() {
        settings = UIDisplaySettings.load(from: file)
    }

    func reload() {
        settings = UIDisplaySettings.load(from: file)
    }

    func updateHome(_ change: (inout HomeDisplaySettings) -> Void) {
        var next = settings
        change(&next.home)
        file.save(next)
        settings = next
    }

    var fileURL: URL { file.url }
}
