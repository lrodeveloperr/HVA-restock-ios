import SwiftUI
import HVACRestockCore

struct CSVImportReview: View {
    @Environment(\.dismiss) private var dismiss
    let preview: CSVImportPreview
    let store: InventoryStore
    let purchase: PurchaseManager

    @State private var mergeDuplicates = true
    @State private var showUnlock = false
    @State private var errorMessage: String?

    private var existingKeys: Set<String> {
        Set(store.items.map { duplicateKey($0.snapshot) })
    }

    private var duplicateRowCount: Int {
        var seen = existingKeys
        var duplicates = 0
        for row in preview.rows {
            let key = duplicateKey(row.draft)
            if seen.contains(key) { duplicates += 1 }
            else { seen.insert(key) }
        }
        return duplicates
    }

    private var newItemCount: Int {
        InventoryRules.newItemCount(
            existingKeys: existingKeys,
            incomingKeys: preview.rows.map { duplicateKey($0.draft) },
            mergeDuplicates: mergeDuplicates
        )
    }

    private var exceedsFreeLimit: Bool {
        InventoryRules.requiresLifetimeUnlock(
            currentItems: store.activeItemCount,
            newItems: newItemCount,
            unlocked: purchase.isUnlocked
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Valid rows", value: String(preview.rows.count))
                    LabeledContent("Rows with errors", value: String(preview.issues.count))
                    LabeledContent("Duplicate matches", value: String(duplicateRowCount))
                    Toggle("Merge duplicate matches", isOn: $mergeDuplicates)
                } footer: {
                    Text("Merging adds the imported quantity to the matching item and updates its restock levels. Invalid rows are skipped only if you continue.")
                }

                if exceedsFreeLimit {
                    Section {
                        Button("Unlock unlimited items for \(purchase.priceText)") { showUnlock = true }
                    } footer: {
                        Text("This import would create \(newItemCount) items, taking the truck stock above the 10-item free limit. This is a one-time purchase, not a subscription.")
                    }
                }

                Section("Items to import") {
                    ForEach(preview.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.draft.name).font(.headline)
                                Spacer()
                                Text("\(row.draft.quantity)").font(.headline.monospacedDigit())
                            }
                            Text("Line \(row.sourceLine) • \(row.draft.category.label)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if !preview.issues.isEmpty {
                    Section("Rows that will be skipped") {
                        ForEach(preview.issues) { issue in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Line \(issue.sourceLine)").font(.headline)
                                Text(issue.message).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(exceedsFreeLimit ? "Unlock" : "Import") {
                        if exceedsFreeLimit { showUnlock = true }
                        else { runImport() }
                    }
                    .fontWeight(.semibold)
                    .disabled(preview.rows.isEmpty)
                }
            }
            .sheet(isPresented: $showUnlock) {
                LifetimeUnlockView(purchase: purchase)
            }
            .alert("Import failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Try again.")
            }
        }
    }

    private func runImport() {
        do {
            try store.importRows(preview.rows, mergeDuplicates: mergeDuplicates, unlocked: purchase.isUnlocked)
            dismiss()
        } catch {
            if let storeError = error as? InventoryStoreError,
               case .freeLimitReached = storeError {
                showUnlock = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func duplicateKey(_ draft: InventoryDraft) -> String {
        InventoryRules.duplicateKey(
            name: draft.name,
            partNumber: draft.partNumber,
            category: draft.category,
            location: draft.location
        )
    }

    private func duplicateKey(_ item: InventorySnapshot) -> String {
        InventoryRules.duplicateKey(
            name: item.name,
            partNumber: item.partNumber,
            category: item.category,
            location: item.location
        )
    }
}
