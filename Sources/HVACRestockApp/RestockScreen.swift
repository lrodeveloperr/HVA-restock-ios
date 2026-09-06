import SwiftUI
import HVACRestockCore

struct RestockScreen: View {
    let store: InventoryStore

    @State private var selectedItem: InventoryItem?
    @State private var stockAmount = 1
    @State private var errorMessage: String?

    var body: some View {
        GoodUseFrame { runtime in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if store.lowStockItems.isEmpty {
                        GUSection {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(runtime.palette.success)
                                    .accessibilityHidden(true)
                                Text("Nothing to restock").font(.headline)
                                Text("Items appear here automatically when they reach their restock level.")
                                    .font(.subheadline)
                                    .foregroundStyle(runtime.palette.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        HStack {
                            Text("\(store.lowStockItems.count) item\(store.lowStockItems.count == 1 ? "" : "s") to buy")
                                .font(.subheadline)
                                .foregroundStyle(runtime.palette.secondary)
                            Spacer()
                            ShareLink(
                                item: CSVShareFile(text: store.restockCSV(), filename: "HVAC-Restock-List.csv"),
                                preview: SharePreview("HVAC restock list")
                            ) {
                                Label("CSV", systemImage: "square.and.arrow.up")
                                    .frame(minHeight: 44)
                            }
                        }

                        ForEach(store.lowStockItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { item in
                            RestockCard(item: item) {
                                stockAmount = max(1, InventoryRules.suggestedPurchase(onHand: item.quantity, restockTo: item.restockTo))
                                selectedItem = item
                            }
                        }
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Restock")
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                Form {
                    Section {
                        LabeledContent("Item", value: item.name)
                        LabeledContent("On truck", value: String(item.quantity))
                        LabeledContent("Restock to", value: String(item.restockTo))
                    }
                    Section("Quantity received") {
                        QuantityField(label: "Add", value: $stockAmount, minimum: 1)
                    }
                }
                .navigationTitle("Stock item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { selectedItem = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Stock") {
                            do {
                                try store.stock(item, amount: stockAmount)
                                selectedItem = nil
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Couldn’t stock item", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }
}

private struct RestockCard: View {
    @Environment(\.guRuntime) private var runtime
    let item: InventoryItem
    let stockAction: () -> Void

    var body: some View {
        let palette = runtime?.palette ?? GUPalettes.light
        let buy = InventoryRules.suggestedPurchase(onHand: item.quantity, restockTo: item.restockTo)
        GUSection {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name).font(.headline)
                    if !item.partNumber.isEmpty {
                        Text(item.partNumber).font(.subheadline.monospaced()).foregroundStyle(palette.secondary)
                    }
                    if !item.location.isEmpty {
                        Label(item.location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(palette.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Buy \(buy)").font(.title3.bold())
                    Text("\(item.quantity) on truck").font(.caption).foregroundStyle(palette.secondary)
                }
            }
            Button(action: stockAction) {
                Text("Stock").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Stock \(item.name), suggested quantity \(buy)")
        }
    }
}
