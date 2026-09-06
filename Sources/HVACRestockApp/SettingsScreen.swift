import SwiftUI

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    let store: InventoryStore
    let purchase: PurchaseManager
    let requestImport: () -> Void

    @State private var showUnlock = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lifetime access") {
                    LabeledContent("Status", value: purchase.isUnlocked ? "Unlocked" : "Free — 10 items")
                    if !purchase.isUnlocked {
                        Button("Unlock for \(purchase.priceText)") { showUnlock = true }
                    }
                    Button("Restore purchase") {
                        Task { await purchase.restore() }
                    }
                    .disabled(purchase.isBusy)

                    if let message = purchase.message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Your data") {
                    Button {
                        requestImport()
                    } label: {
                        Label("Import inventory CSV", systemImage: "square.and.arrow.down")
                    }

                    ShareLink(
                        item: CSVShareFile(text: store.inventoryCSV(), filename: "HVAC-Truck-Stock.csv"),
                        preview: SharePreview("HVAC truck stock")
                    ) {
                        Label("Export inventory CSV", systemImage: "square.and.arrow.up")
                    }

                    Text("Records stay on this device and follow normal iPhone backup behavior. No account or publisher cloud is used.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    Link("Privacy policy", destination: AppLinks.privacy)
                    Link("Terms", destination: AppLinks.terms)
                    LabeledContent("Purchase", value: "One time")
                    LabeledContent("Accounts, ads, analytics", value: "None")
                }

                Section {
                    Button("Delete all app data", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("Deletes inventory and activity from this device. A lifetime purchase remains restorable through the App Store.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showUnlock) {
                LifetimeUnlockView(purchase: purchase)
            }
            .confirmationDialog(
                "Delete all inventory and activity?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete all data", role: .destructive) { deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Couldn’t delete data", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Try again.")
            }
        }
    }

    private func deleteAll() {
        do { try store.deleteAllData() }
        catch { errorMessage = error.localizedDescription }
    }
}
