import SwiftUI

/// "살까요?" before churu leaves the ledger.
struct StorePurchaseConfirmation: View {
    let pending: PendingPurchase
    let theme: RoomTheme
    /// While the purchase runs the dialog stays up with its buttons off.
    var busy = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        StoreDialog(theme: theme) {
            Text(pending.product == .catBox ? "Open the adoption box?" : "Buy \(pending.name)?" as LocalizedStringResource)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(pending.price == 0 ? "Free" : "Spends \(TokenCount.compact(pending.price)) churu" as LocalizedStringResource)
                .font(.system(size: 11, design: .rounded)).opacity(0.75)
            HStack {
                Button("Cancel", action: onCancel)
                Button(pending.product == .catBox ? "Open" : "Buy", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
            .disabled(busy)
        }
    }
}
