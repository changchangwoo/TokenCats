import SwiftUI

/// The words for cat coats and the numbered names built from them.
extension CatDisplayName {
    /// "Cheese", or the coat id itself for a coat added later without a name.
    static func coatTitle(_ coat: String) -> LocalizedStringResource {
        switch coat {
        case "black": return "Black"
        case "white": return "White"
        case "cheese": return "Cheese"
        case "tuxedo": return "Tuxedo"
        case "tabby": return "Tabby"
        case "split": return "Calico"
        case "siamese": return "Siamese"
        case "cream": return "Cream"
        case "foxfire": return "Foxfire"
        case "norwegian": return "Norwegian"
        case "sphynx": return "Sphynx"
        default: return LocalizedStringResource(String.LocalizationValue(coat))
        }
    }

    var coatName: LocalizedStringResource { Self.coatTitle(coat) }

    /// "Cheese" or "Cheese 2".
    var text: LocalizedStringResource {
        ordinal.map { "\(coatName) \($0)" } ?? coatName
    }
}
