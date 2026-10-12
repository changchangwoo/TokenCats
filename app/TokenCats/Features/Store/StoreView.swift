import SwiftUI

/// The churu store inside the open notch: a front page with adoption, a horizontally browsable room shelf and a
/// prop shelf below it, and the adoption box as its own small event. Tapping an owned background applies it and an
/// owned prop places it, right here; 보관함 does the same and manages the cats.
struct StoreView: View {
    @ObservedObject private var store = StoreModel.shared
    @ObservedObject private var churu = ChuruModel.shared
    @ObservedObject private var coordinator = NotchCoordinator.shared
    @AppStorage(AppSettings.Key.roomTheme) private var backgroundID = AppSettings.Default.roomTheme
    @StateObject private var notice = Notice()
    @Environment(\.locale) private var locale
    @State private var confirming: PendingPurchase?
    @State private var reveal: PurchaseResult?
    @State private var visibleRoomID: String?

    private var theme: RoomTheme { store.theme(id: backgroundID) }
    private var balance: Int { churu.snapshot?.balance ?? 0 }

    var body: some View {
        ScreenFrame(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                if let catalog = store.catalog {
                    switch store.route {
                    case .main:
                        front(catalog)
                    case .adopt:
                        StoreAdoptionView(catalog: catalog, theme: theme, balance: balance, busy: store.busy,
                                          onBack: { open(.main) }, onConfirm: { ask($0) })
                    }
                } else {
                    ScreenHeader(theme: theme, back: nil, title: "Store") { }
                    Text("The store is getting ready.").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let message = notice.message {
                    Text(message).font(.system(size: 11, weight: .medium, design: .rounded)).opacity(0.85)
                }
            }
        }
        .overlay {
            // The confirmation stays up while the purchase runs, then gives way to what it bought in one move.
            if let confirming {
                StorePurchaseConfirmation(pending: confirming, theme: theme, busy: store.busy,
                                          onCancel: { ask(nil) }) {
                    Task { await buy(confirming) }
                }
                .transition(.opacity)
            }
            if let reveal {
                StoreRevealCard(result: reveal, theme: theme, household: store.household,
                                onClose: { withAnimation(StoreDialogMotion.animation) { self.reveal = nil } },
                                onOpenCats: openCats)
                    .transition(.opacity)
            }
        }
        .task { if churu.snapshot == nil { await churu.refresh() } }
        // A background applied here reaches the profile card the same way as one applied in 보관함.
        .onChange(of: backgroundID) { _, _ in
            Task { await ProfileSync.shared.syncIfDue() }
        }
    }

    // MARK: Front page

    private func front(_ catalog: StoreCatalog) -> some View {
        let backgrounds = frontBackgrounds(catalog)
        return VStack(alignment: .leading, spacing: 10) {
            ScreenHeader(theme: theme, back: nil, title: "Store") { }
            // Everything under the header scrolls as one page: adoption, the room shelf, then props.
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    adoptionTeaser(catalog)
                    roomShelf(catalog, backgrounds: backgrounds)
                    if !catalog.propsForSale.isEmpty {
                        propShelf(catalog)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
        }
    }

    private func roomShelf(_ catalog: StoreCatalog, backgrounds: [RoomThemeCatalog.Background]) -> some View {
        GeometryReader { geometry in
            let visibleCount = max(1, Int((geometry.size.width + 10) / 190))
            let lastIndex = max(0, backgrounds.count - visibleCount)
            let currentIndex = min(backgrounds.firstIndex { $0.id == visibleRoomID } ?? 0, lastIndex)
            VStack(alignment: .leading, spacing: 8) {
                Text("Decorate the room").font(.system(size: 13, weight: .bold, design: .rounded))
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(backgrounds, id: \.id) { background in
                            backgroundTile(background, price: catalog.price(ofBackground: background.id) ?? 0)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $visibleRoomID, anchor: .leading)
                .scrollIndicators(.hidden)
                .frame(height: 112)
                .overlay(alignment: .leading) {
                    if currentIndex > 0 {
                        roomArrow(pointsRight: false, label: "Previous rooms") {
                            withAnimation(.easeInOut(duration: 0.55)) {
                                visibleRoomID = backgrounds[currentIndex - 1].id
                            }
                        }
                        .padding(.leading, 6)
                    }
                }
                .overlay(alignment: .trailing) {
                    if currentIndex < lastIndex {
                        roomArrow(pointsRight: true, label: "Next rooms") {
                            withAnimation(.easeInOut(duration: 0.55)) {
                                visibleRoomID = backgrounds[currentIndex + 1].id
                            }
                        }
                        .padding(.trailing, 6)
                    }
                }
            }
        }
        .frame(height: 136)
    }

    private func roomArrow(pointsRight: Bool, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelShelfArrow(pointsRight: pointsRight)
                .fill(theme.accent.swiftUI)
                .frame(width: 21, height: 15)
                .frame(width: 32, height: 36)
                .background(RoundedRectangle(cornerRadius: 7)
                    .fill(theme.surface.swiftUI.opacity(0.74)))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(theme.ink.swiftUI.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private struct PixelShelfArrow: Shape {
        let pointsRight: Bool

        func path(in rect: CGRect) -> Path {
            let pixel = min(rect.width / 7, rect.height / 5)
            let left = rect.midX - pixel * 3.5
            let top = rect.midY - pixel * 2.5
            var path = Path()
            let pixels = [(4, 0), (5, 1), (0, 2), (1, 2), (2, 2), (3, 2),
                          (4, 2), (5, 2), (6, 2), (5, 3), (4, 4)]
            for (column, row) in pixels {
                let x = pointsRight ? column : 6 - column
                path.addRect(CGRect(x: left + CGFloat(x) * pixel,
                                    y: top + CGFloat(row) * pixel,
                                    width: pixel, height: pixel))
            }
            return path
        }
    }

    // MARK: Props

    /// Props on their own shelf under the rooms: just the prop, as it stands in the room, not a whole room.
    private func propShelf(_ catalog: StoreCatalog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Props").font(.system(size: 13, weight: .bold, design: .rounded))
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(catalog.propsForSale, id: \.self) { prop in
                        propTile(prop, price: catalog.price(ofProp: prop) ?? 0)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func propTile(_ prop: RoomProp, price: Int) -> some View {
        let offer = propState(prop, price: price)
        return Button {
            quickPropAction(prop, offer: offer)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(theme.preview.swiftUI)
                    // At room size when it fits, shrunk to fit when it is taller than the tile.
                    if let art = prop.art, let image = RoomArtImages.image(art.image) {
                        Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
                            .frame(maxWidth: Double(art.width), maxHeight: Double(art.height))
                            .padding(5)
                    }
                }
                .frame(width: 108, height: 63)
                Text(prop.title).font(.system(size: 11, weight: .bold, design: .rounded)).lineLimit(1)
                Text(propActionLabel(offer))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .opacity(0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(store.busy)
        .accessibilityLabel(Text("\(prop.title) \(propActionLabel(offer))" as LocalizedStringResource))
        .padding(6)
        .frame(width: 120)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
    }

    private func quickPropAction(_ prop: RoomProp, offer: OfferState) {
        switch offer {
        case .inUse:
            notice.show("Already placed")
        case .owned:
            // Say what it pushed out when its slot was taken, so nothing disappears unnoticed.
            let replaced = store.inventory.decor.prop(in: prop.slot)
            Task {
                guard await store.setProp(prop, shown: true) else {
                    notice.show("Could not save. Please try again")
                    return
                }
                notice.show(replaced.map { "Placed \(prop.title) instead of \($0.title)" } ?? "Placed \(prop.title)")
            }
        case .short(_, let by):
            notice.show("\(TokenCount.compact(by)) churu short")
        case .affordable(let price):
            ask(PendingPurchase(product: .prop(prop), name: prop.title, price: price))
        }
    }

    private func propActionLabel(_ offer: OfferState) -> LocalizedStringResource {
        switch offer {
        case .inUse: return "Placed"
        case .owned: return "Place"
        default: return tileActionLabel(offer)
        }
    }

    private func propState(_ prop: RoomProp, price: Int) -> OfferState {
        OfferState.of(price: price, balance: balance, owned: store.inventory.owns(prop: prop),
                      inUse: store.inventory.decor.shows(prop))
    }

    private func frontBackgrounds(_ catalog: StoreCatalog) -> [RoomThemeCatalog.Background] {
        RoomThemeCatalog.bundled.backgrounds.filter { catalog.price(ofBackground: $0.id) != nil }
    }

    private func adoptionTeaser(_ catalog: StoreCatalog) -> some View {
        let coats = catalog.showcaseCoats(available: CatSprites.shared.hasArt(coat:))
        // The box stays in the middle: the cats split evenly around it (the odd one goes left) and each side
        // keeps an equal share of the width, so a long side never pushes the box over.
        let leftCount = (coats.count + 1) / 2
        return Button {
            open(.adopt)
        } label: {
            VStack(alignment: .center, spacing: 8) {
                Text("Meet a new friend")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                HStack(spacing: 10) {
                    HStack(spacing: 12) {
                        ForEach(Array(coats.prefix(leftCount)), id: \.self) { coat in
                            CatFace(coat: coat).frame(width: 40, height: 40)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    ZStack(alignment: .bottom) {
                        StoreBoxArt(theme: theme, size: 62)
                        Text("Adopt")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.surface.swiftUI)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Capsule().fill(theme.accent.swiftUI))
                            .offset(y: 5)
                    }
                    .frame(width: 80, height: 68)
                    HStack(spacing: 12) {
                        ForEach(Array(coats.dropFirst(leftCount)), id: \.self) { coat in
                            CatFace(coat: coat).frame(width: 40, height: 40)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
                .accessibilityHidden(true)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(theme.surface.swiftUI))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adopt: meet a new friend")
    }

    private func backgroundTile(_ background: RoomThemeCatalog.Background, price: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                quickBackgroundAction(background, price: price)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    RoomPreview(theme: background.theme)
                        .frame(width: 168, height: 63)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    HStack {
                        Text(verbatim: background.name.resolve(for: locale)).font(.system(size: 11, weight: .bold, design: .rounded))
                        Spacer()
                        Text(tileActionLabel(state(of: background.id, price: price)))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .opacity(0.8)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(store.busy)
            .accessibilityLabel(Text("\(background.name.resolve(for: locale)) \(tileActionLabel(state(of: background.id, price: price)))" as LocalizedStringResource))
        }
        .padding(6)
        .frame(width: 180, height: 112)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(theme.accent.swiftUI, lineWidth: background.id == theme.id ? 2 : 0))
    }

    private func quickBackgroundAction(_ background: RoomThemeCatalog.Background, price: Int) {
        switch state(of: background.id, price: price) {
        case .inUse:
            notice.show("This background is in use")
        case .owned:
            withAnimation(.smooth(duration: 0.3)) { backgroundID = background.id }
            notice.show("Applied the \(background.name.resolve(for: locale)) background")
        case .short(_, let by):
            notice.show("\(TokenCount.compact(by)) churu short")
        case .affordable(let price):
            ask(PendingPurchase(product: .background(background.id),
                                name: "the \(background.name.resolve(for: locale)) background", price: price))
        }
    }

    private func tileActionLabel(_ offer: OfferState) -> LocalizedStringResource {
        switch offer {
        case .inUse: return "In use"
        case .owned: return "Apply"
        case .affordable(let price): return "Buy · \(StoreFormat.short(price))"
        case .short(let price, _): return StoreFormat.churu(price)
        }
    }

    private func state(of backgroundID: String, price: Int) -> OfferState {
        OfferState.of(price: price, balance: balance, owned: store.inventory.owns(background: backgroundID),
                      inUse: theme.id == backgroundID)
    }

    // MARK: Routing and purchase

    private func open(_ route: StoreRoute) {
        withAnimation(.smooth) { store.route = route }
    }

    private func ask(_ pending: PendingPurchase?) {
        withAnimation(StoreDialogMotion.animation) { confirming = pending }
    }

    private func openCats() {
        withAnimation(.smooth(duration: 0.28)) {
            reveal = nil
            store.route = .main
            coordinator.currentView = .cats
        }
    }

    private func buy(_ pending: PendingPurchase) async {
        let result = await store.purchase(pending.product)
        let message: LocalizedStringResource?
        switch result {
        case .adopted, .backgroundOwned, .propOwned, .treated:
            message = nil
        case .insufficient(let short):
            message = "\(TokenCount.compact(short)) churu short"
        case .alreadyOwned:
            message = "Already owned"
        case .failed:
            message = "Purchase failed. Your churu is untouched"
        }
        withAnimation(StoreDialogMotion.animation) {
            confirming = nil
            if message == nil { reveal = result }
        }
        if let message { notice.show(message) }
    }
}
