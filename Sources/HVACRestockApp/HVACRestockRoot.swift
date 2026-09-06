import SwiftUI
import SwiftData

enum InitialAction: String {
    case none
    case add
    case importCSV
}

public struct HVACRestockRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hvacRestock.onboardingComplete") private var onboardingComplete = false
    @State private var store: InventoryStore?
    @State private var purchase = PurchaseManager()
    @State private var initialAction: InitialAction = .none

    public init() {}

    public var body: some View {
        Group {
            if !onboardingComplete {
                StartView(
                    addAction: {
                        initialAction = .add
                        onboardingComplete = true
                    },
                    importAction: {
                        initialAction = .importCSV
                        onboardingComplete = true
                    }
                )
            } else if let store {
                MainTabs(store: store, purchase: purchase, initialAction: $initialAction)
            } else {
                ProgressView("Opening truck stock…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { prepareStore() }
            }
        }
        .task {
            prepareStore()
            await purchase.load()
        }
        .task {
            await purchase.observeTransactionUpdates()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            store?.refresh()
            Task { await purchase.refreshEntitlement() }
        }
    }

    private func prepareStore() {
        guard store == nil else { return }
        store = InventoryStore(context: modelContext)
    }
}

private struct StartView: View {
    let addAction: () -> Void
    let importAction: () -> Void

    var body: some View {
        GoodUseFrame { runtime in
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 36)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(runtime.palette.primary)
                    .accessibilityHidden(true)
                Text("HVAC Restock")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(runtime.palette.text)
                Text("Use a part. Your supply-house list updates automatically.")
                    .font(.system(size: 18))
                    .foregroundStyle(runtime.palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                GUPrimary("Add items", icon: "plus", action: addAction)
                GUSecondary("Import CSV", action: importAction)
                Text("No account. No ads. Your records stay on this device.")
                    .font(.footnote)
                    .foregroundStyle(runtime.palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)
            }
        }
    }
}

#if DEBUG
#Preview("Fresh install") {
    StartView(addAction: {}, importAction: {})
}
#endif
