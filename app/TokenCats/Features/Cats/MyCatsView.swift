import SwiftUI

/// 보관함: owned backgrounds, the cats in the room (shown on Home), the other cats ("고양이"), and props, with
/// moving cats between the room and the rest. A full room brings a stored cat in by trading places with a room cat.
/// Right-clicking a cat offers to release it, which removes it for good after a confirmation.
struct MyCatsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store = StoreModel.shared
    @ObservedObject private var bonds = CatBondModel.shared
    @AppStorage(AppSettings.Key.roomTheme) private var backgroundID = AppSettings.Default.roomTheme
    @StateObject private var notice = Notice()
    @Environment(\.locale) private var locale
    @Namespace private var catMovement
    /// A stored cat waiting for a room cat to trade places with.
    @State private var swapping: CatResidentRecord?
    /// A cat waiting for "release for good?" to be answered.
    @State private var releasing: CatResidentRecord?
    /// A cat whose name is being typed, and the text so far.
    @State private var renaming: CatResidentRecord?
    @State private var nameDraft = ""
    @FocusState private var nameFieldFocused: Bool
    @ObservedObject private var coordinator = NotchCoordinator.shared

    private var theme: RoomTheme { store.theme(id: backgroundID) }

    var body: some View {
        let household = store.household
        ScreenFrame(theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                ScreenHeader(theme: theme, back: nil, title: "Collection") { }
                // Everything under the header scrolls as one page: owned backgrounds, cats, then props.
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        backgrounds
                        section(title: "Room \(household.roomResidents.count)/\(CatHousehold.roomCapacity)",
                                hint: swapping == nil ? "" : "Tap the cat to swap out",
                                cats: household.roomResidentsByEntry, inRoom: true)
                        if let swapping {
                            swapBanner(for: swapping)
                        }
                        section(title: "Cats \(household.storedResidents.count)",
                                hint: household.isRoomFull ? "Room is full · tap to swap" : "Tap to move into the room",
                                cats: household.storedResidents, inRoom: false)
                        props
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.automatic)
                if let message = notice.message {
                    Text(message)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .opacity(0.85)
                }
            }
        }
        .overlay {
            if let releasing {
                releaseConfirmation(for: releasing).transition(.opacity)
            } else if let renaming {
                renameDialog(for: renaming).transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.36), value: household)
        .onChange(of: backgroundID) { _, _ in
            Task { await ProfileSync.shared.syncIfDue() }
        }
    }

    private var backgrounds: some View {
        let owned = RoomThemeCatalog.bundled.backgrounds.filter { store.inventory.owns(background: $0.id) }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Backgrounds").font(.system(size: 12, weight: .bold, design: .rounded))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(owned, id: \.id) { background in
                    let selected = theme.id == background.id
                    Button {
                        withAnimation(.smooth(duration: 0.3)) { backgroundID = background.id }
                        notice.show("Applied the \(background.name.resolve(for: locale)) background")
                    } label: {
                        VStack(spacing: 3) {
                            RoomPreview(theme: background.theme)
                                .frame(height: 35)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            HStack(spacing: 3) {
                                Text(verbatim: background.name.resolve(for: locale))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(theme.accent.swiftUI)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 7).fill(theme.surface.swiftUI))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(theme.accent.swiftUI, lineWidth: selected ? 2 : 0))
                    }
                    .buttonStyle(.plain)
                    .disabled(selected)
                    .accessibilityLabel(Text("\(background.name.resolve(for: locale)) background, \((selected ? "In use" : "Apply") as LocalizedStringResource)" as LocalizedStringResource))
                }
            }
        }
    }

    /// Owned props, one row each: what it is, where it goes, and a button to put it in the room or take it out.
    /// A prop whose slot is taken replaces the one there.
    private var props: some View {
        let owned = RoomProp.allCases.filter { store.inventory.owns(prop: $0) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Props").font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                if owned.allSatisfy(\.isStarter) {
                    Text("Props are sold in the store")
                        .font(.system(size: 10, weight: .medium, design: .rounded)).opacity(0.7)
                }
            }
            ForEach(owned, id: \.self) { prop in
                let shown = store.inventory.decor.shows(prop)
                HStack(spacing: 10) {
                    PropIcon(prop: prop, scale: 0.5)
                        .frame(width: 40, height: 34)
                        .background(RoundedRectangle(cornerRadius: 5).fill(theme.preview.swiftUI))
                        .opacity(shown ? 1 : 0.5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(prop.title).font(.system(size: 12, weight: .bold, design: .rounded))
                        Text("\(prop.slot.title) · \((shown ? "Placed" : "Put away") as LocalizedStringResource)" as LocalizedStringResource)
                            .font(.system(size: 10, design: .rounded)).opacity(0.7)
                    }
                    Spacer()
                    Button {
                        Task {
                            if !(await store.setProp(prop, shown: !shown)) { notice.show("Could not save. Please try again") }
                        }
                    } label: {
                        Text(shown ? "Remove" : "Place")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle((shown ? theme.ink : theme.surface).swiftUI)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(shown ? theme.panel.swiftUI : theme.accent.swiftUI))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(prop.title) \((shown ? "Remove" : "Place") as LocalizedStringResource)" as LocalizedStringResource))
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
            }
        }
    }

    private func section(title: LocalizedStringResource, hint: LocalizedStringResource, cats: [CatResidentRecord], inRoom: Bool,
                         columns: Int = 6) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Text(hint).font(.system(size: 10, weight: .medium, design: .rounded)).opacity(0.7)
            }
            if cats.isEmpty {
                Text(inRoom ? "The room is empty" : "No cats outside the room")
                    .font(.system(size: 11, design: .rounded))
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI.opacity(0.6)))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(84), spacing: 8), count: columns),
                          alignment: .leading, spacing: 8) {
                    ForEach(cats, id: \.id) { cat in card(cat, inRoom: inRoom) }
                }
            }
        }
    }

    private func card(_ cat: CatResidentRecord, inRoom: Bool) -> some View {
        let chosen = swapping?.id == cat.id
        let target = swapping != nil && inRoom
        return Button {
            Task { await tap(cat) }
        } label: {
            VStack(spacing: 3) {
                CatFace(coat: cat.coat)
                    .frame(width: 44, height: 44)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(theme.preview.swiftUI.opacity(inRoom ? 1 : 0.55)))
                Text(CatNames.display(cat, in: store.household).text)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("Lv.\(bonds.level(of: cat.id))")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .opacity(0.8)
                    BondBar(progress: bonds.progress(of: cat.id), theme: theme)
                }
                .padding(.horizontal, 2)
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(theme.accent.swiftUI, lineWidth: chosen || target ? 2 : 0))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let price = store.catalog?.treatPrice, bonds.level(of: cat.id) < CatBondRules.maxLevel {
                let priceText = AppLanguage.shared.string(StoreFormat.churu(price))
                Button("Give churu · \(priceText)") { Task { await giveTreat(cat) } }
            }
            Button("Rename…") {
                nameDraft = cat.name ?? ""
                withAnimation(StoreDialogMotion.animation) { swapping = nil; renaming = cat }
            }
            Button("Release…", role: .destructive) {
                withAnimation(StoreDialogMotion.animation) { swapping = nil; releasing = cat }
            }
        }
        .matchedGeometryEffect(id: cat.id, in: catMovement)
        .accessibilityLabel(Text("\(CatNames.display(cat, in: store.household).text), \((inRoom ? "In the room" : "Outside") as LocalizedStringResource)" as LocalizedStringResource))
    }

    /// Typing happens inside the notch: while this dialog is up the notch stays open and its window takes the
    /// keyboard (`NotchCoordinator.takesTyping`). Return saves, Escape cancels.
    private func renameDialog(for cat: CatResidentRecord) -> some View {
        let display = CatNames.display(cat, in: store.household)
        let coatName = CatDisplayName(coat: cat.coat, ordinal: display.ordinal).text
        return StoreDialog(theme: theme) {
            CatFace(coat: cat.coat).frame(width: 44, height: 44)
            Text("Name this cat")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            TextField(text: $nameDraft, prompt: Text(coatName)) { Text("Name") }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .rounded))
                .frame(width: 220)
                .focused($nameFieldFocused)
                .onSubmit { saveName(for: cat) }
                .onChange(of: nameDraft) { _, text in
                    if text.count > CatNames.maxNameLength { nameDraft = String(text.prefix(CatNames.maxNameLength)) }
                }
            Text("Leave it blank to use the coat name again.")
                .font(.system(size: 11, design: .rounded)).opacity(0.75)
            HStack {
                Button("Cancel") { endRenaming() }.keyboardShortcut(.cancelAction)
                Button("Save") { saveName(for: cat) }.keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            coordinator.takesTyping = true
            Task {
                try? await Task.sleep(for: .milliseconds(80))
                nameFieldFocused = true
            }
        }
        .onDisappear { coordinator.takesTyping = false }
    }

    private func saveName(for cat: CatResidentRecord) {
        let name = nameDraft
        endRenaming()
        Task {
            let error = await store.rename(id: cat.id, to: name)
            report(error)
            if error == nil, let renamed = store.household.residents.first(where: { $0.id == cat.id }) {
                notice.show("Now called \(CatNames.display(renamed, in: store.household).text)" as LocalizedStringResource)
            }
        }
    }

    private func endRenaming() {
        nameFieldFocused = false
        withAnimation(StoreDialogMotion.animation) { renaming = nil }
    }

    private func releaseConfirmation(for cat: CatResidentRecord) -> some View {
        let name = CatNames.display(cat, in: store.household).text
        return StoreDialog(theme: theme) {
            CatFace(coat: cat.coat).frame(width: 44, height: 44)
            Text("Release \(name)?" as LocalizedStringResource)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text("It leaves for good and can't be brought back. The churu spent on it is not returned.")
                .font(.system(size: 11, design: .rounded)).opacity(0.75)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            HStack {
                Button("Cancel") { withAnimation(StoreDialogMotion.animation) { releasing = nil } }
                Button("Release", role: .destructive) {
                    withAnimation(StoreDialogMotion.animation) { releasing = nil }
                    Task {
                        let error = await store.release(id: cat.id)
                        report(error)
                        if error == nil { notice.show("Released \(name)" as LocalizedStringResource) }
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func swapBanner(for cat: CatResidentRecord) -> some View {
        HStack {
            CatFace(coat: cat.coat).frame(width: 22, height: 22)
            Text("Tap a room cat to swap with \(CatNames.display(cat, in: store.household).text)" as LocalizedStringResource)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Spacer()
            Button("Cancel") { withAnimation(.smooth) { swapping = nil } }
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
    }

    private func tap(_ cat: CatResidentRecord) async {
        if cat.inRoom {
            if let stored = swapping {
                withAnimation(.smooth) { swapping = nil }
                report(await store.swap(roomID: cat.id, storedID: stored.id))
            } else {
                report(await store.move(id: cat.id, toRoom: false))
            }
        } else if store.household.isRoomFull {
            withAnimation(.smooth) { swapping = swapping?.id == cat.id ? nil : cat }
        } else {
            report(await store.move(id: cat.id, toRoom: true))
        }
    }

    private func giveTreat(_ cat: CatResidentRecord) async {
        let name = CatNames.display(cat, in: store.household).text
        switch await store.purchase(.treat(catID: cat.id)) {
        case .treated(_, let level):
            notice.show("\(name) enjoyed the churu · Lv.\(level)")
        case .insufficient(let short):
            notice.show("Not enough churu · \(TokenCount.compact(short)) short")
        case .alreadyOwned:
            notice.show("Already at Lv.\(CatBondRules.maxLevel)")
        default:
            notice.show("Could not give churu. Please try again")
        }
    }

    private func report(_ error: CatHousehold.MoveError?) {
        switch error {
        case nil: break
        case .roomFull?: notice.show("The room is full. Tap a cat below to swap")
        case .lastCatInRoom?: notice.show("One cat has to stay in the room")
        case .saveFailed?: notice.show("Could not save. Please try again")
        case .unknownCat?, .notASwap?: notice.show("Could not find that cat")
        }
    }
}

/// A prop drawn the way it looks in the room, scaled into a card.
private struct PropIcon: View {
    let prop: RoomProp
    var scale = 0.8
    @ObservedObject private var churu = ChuruModel.shared

    var body: some View {
        switch prop {
        case .calendar:
            // The calendar is 48×60pt in the room, scaled down to fit its row.
            Canvas { graphics, size in
                graphics.translateBy(x: (size.width - 48 * scale) / 2, y: (size.height - 60 * scale) / 2)
                graphics.scaleBy(x: scale, y: scale)
                RoomPainter.calendar(CalendarProp(top: 0, calendar: churu.wallCalendar), in: graphics, left: 0)
            }
        default:
            if let art = prop.art, let image = RoomArtImages.image(art.image) {
                Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
                    .frame(maxWidth: Double(art.width) * scale, maxHeight: Double(art.height) * scale)
                    .padding(2)
            }
        }
    }
}
