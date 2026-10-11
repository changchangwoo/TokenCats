import SwiftUI

/// The adoption box: on the left the box and its button, on the right every tier it can give, each with its
/// chance and cats. Tapping a tier's count lists its cats with each one's own chance.
struct StoreAdoptionView: View {
    let catalog: StoreCatalog
    let theme: RoomTheme
    let balance: Int
    let busy: Bool
    let onBack: () -> Void
    let onConfirm: (PendingPurchase) -> Void

    var body: some View {
        let price = catalog.catBox.price
        let odds = catalog.boxOdds(available: CatSprites.shared.hasArt(coat:))
        VStack(spacing: 0) {
            ScreenHeader(theme: theme, back: "Store", title: "Adoption", onBack: onBack)
            HStack(alignment: .top, spacing: 16) {
                boxColumn(price: price)
                    .frame(width: 224)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Possible cats").font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer(minLength: 0)
                        Text("Drop rates").font(.system(size: 10, design: .rounded)).opacity(0.7)
                    }
                    ForEach(odds, id: \.tier.id) { odd in
                        AdoptionTierCard(odds: odd, theme: theme)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 8)
        }
    }

    private func boxColumn(price: Int) -> some View {
        let offer = OfferState.of(price: price, balance: balance, owned: false, inUse: false)
        return VStack(spacing: 10) {
            Spacer(minLength: 0)
            StoreBoxArt(theme: theme, size: 76)
            VStack(spacing: 3) {
                Text("Adoption box").font(.system(size: 17, weight: .heavy, design: .rounded))
                Text("Meet your next little companion")
                    .font(.system(size: 11, design: .rounded)).opacity(0.75)
            }
            VStack(spacing: 5) {
                StoreOfferButton(offer: offer, name: "Adoption", theme: theme, busy: busy,
                                 affordableTitle: "Open · \(StoreFormat.short(price))",
                                 shortTitle: "Open · \(StoreFormat.short(price))") {
                    if case .affordable = offer {
                        onConfirm(PendingPurchase(product: .catBox, name: "the adoption box", price: price))
                    }
                }
                Text(footnote(price: price, offer: offer))
                    .font(.system(size: 10, design: .rounded))
                    .monospacedDigit()
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
        }
    }

    /// "1 cat per box" while the box is free, otherwise the balance against the price.
    private func footnote(price: Int, offer: OfferState) -> LocalizedStringResource {
        if price == 0 { return "1 cat per box" }
        if case .short(_, let by) = offer {
            return "\(TokenCount.compact(balance)) / \(TokenCount.price(price)) churu · \(TokenCount.compact(by)) more needed"
        }
        return "\(TokenCount.compact(balance)) / \(TokenCount.price(price)) churu"
    }
}

/// One tier: a coloured dot, its name and chance, then its cats' faces and how many there are.
private struct AdoptionTierCard: View {
    let odds: StoreCatalog.BoxOdds
    let theme: RoomTheme
    @Environment(\.locale) private var locale
    @State private var listing = false

    /// Faces that fit beside the count; a longer tier ends with "+N".
    private static let maxFaces = 5

    var body: some View {
        let coats = odds.tier.coats
        let shown = coats.count > Self.maxFaces ? Array(coats.prefix(Self.maxFaces - 1)) : coats
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle().fill(Self.tint(odds.tier.id)).frame(width: 6, height: 6)
                Text(verbatim: odds.tier.name.resolve(for: locale))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                Text(verbatim: StoreFormat.percent(odds.percent))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                ForEach(shown, id: \.self) { coat in face(coat) }
                if shown.count < coats.count {
                    Text(verbatim: "+\(coats.count - shown.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.ink.swiftUI.opacity(0.08)))
                }
                Spacer(minLength: 0)
                Button { listing = true } label: {
                    HStack(spacing: 3) {
                        Text("\(coats.count) cats")
                        Image(systemName: "chevron.right").imageScale(.small)
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.75)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $listing, arrowEdge: .trailing) { catList }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9).fill(theme.surface.swiftUI))
    }

    private func face(_ coat: String) -> some View {
        CatFace(coat: coat)
            .frame(width: 24, height: 24)
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 6).fill(theme.ink.swiftUI.opacity(0.08)))
            .help(Text(CatDisplayName.coatTitle(coat)))
    }

    /// Every cat in the tier with its own chance.
    private var catList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(odds.tier.coats, id: \.self) { coat in
                HStack(spacing: 8) {
                    CatFace(coat: coat).frame(width: 24, height: 24)
                    Text(CatDisplayName.coatTitle(coat)).font(.system(size: 12, design: .rounded))
                    Spacer(minLength: 12)
                    Text(verbatim: StoreFormat.percent(odds.percentPerCoat))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .padding(12)
        .frame(minWidth: 180)
    }

    /// Grey, green, blue and gold from common to unique; any other tier takes the common grey.
    private static func tint(_ tier: String) -> Color {
        switch tier {
        case "uncommon": return Color(red: 0.62, green: 0.84, blue: 0.56)
        case "rare": return Color(red: 0.60, green: 0.68, blue: 0.95)
        case "unique": return Color(red: 0.95, green: 0.80, blue: 0.45)
        default: return Color(white: 0.72)
        }
    }
}
