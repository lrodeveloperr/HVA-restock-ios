import SwiftUI
import HVACRestockCore

struct StockScreen: View {
    let store: InventoryStore
    let purchase: PurchaseManager
    let requestAdd: () -> Void

    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?
    @State private var errorMessage: String?

    private var visibleItems: [InventoryItem] {
        let ordered = store.items.sorted { lhs, rhs in
            let lhsRank = InventoryRules.isLowStock(onHand: lhs.quantity, restockAt: lhs.restockAt) ? 0 : 1
            let rhsRank = InventoryRules.isLowStock(onHand: rhs.quantity, restockAt: rhs.restockAt) ? 0 : 1
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return ordered }
        return ordered.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.partNumber.localizedCaseInsensitiveContains(query) ||
            $0.location.localizedCaseInsensitiveContains(query) ||
            $0.category.label.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        GoodUseFrame { runtime in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    summary(runtime)
                    search(runtime)

                    if store.items.isEmpty {
                        emptyState
                    } else if visibleItems.isEmpty {
                        GUSection {
                            ContentUnavailableView.search(text: searchText)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        ForEach(visibleItems) { item in
                            StockItemCard(
                                item: item,
                                useAction: { perform { try store.useOne(item) } },
                                addAction: { perform { try store.addOne(item) } },
                                editAction: { selectedItem = item }
                            )
                        }
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Stock")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: requestAdd) {
                    Label("Add", systemImage: "plus")
                }
                .frame(minHeight: 44)
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemEditor(
                title: "Edit item",
                initial: InventoryDraft(
                    name: item.name,
                    partNumber: item.partNumber,
                    category: item.category,
                    location: item.location,
                    quantity: item.quantity,
                    restockAt: item.restockAt,
                    restockTo: item.restockTo
                ),
                save: { draft in try store.update(item, draft: draft) },
                delete: { try store.delete(item) }
            )
        }
        .alert("Couldn’t update stock", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .safeAreaInset(edge: .bottom) {
            if let action = store.lastAction {
                HStack {
                    Text(action).font(.subheadline).lineLimit(1)
                    Spacer()
                    Button("Dismiss") { store.clearMessages() }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(.regularMaterial)
            }
        }
    }

    @ViewBuilder
    private func summary(_ runtime: GURuntime) -> some View {
        HStack(spacing: 12) {
            SummaryTile(value: String(store.activeItemCount), label: "Items", color: runtime.palette.primary)
            SummaryTile(value: String(store.lowStockItems.count), label: "Low", color: store.lowStockItems.isEmpty ? runtime.palette.success : runtime.palette.warning)
            SummaryTile(value: String(store.items.filter { $0.quantity == 0 }.count), label: "Out", color: store.items.contains { $0.quantity == 0 } ? runtime.palette.error : runtime.palette.success)
        }
        if !purchase.isUnlocked {
            Text("\(store.activeItemCount) of \(InventoryRules.freeItemLimit) free items used")
                .font(.footnote)
                .foregroundStyle(runtime.palette.secondary)
        }
    }

    @ViewBuilder
    private func search(_ runtime: GURuntime) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(runtime.palette.secondary)
            TextField("Item, part number or location", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(runtime.palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(runtime.palette.border))
    }

    private var emptyState: some View {
        GUSection {
            VStack(spacing: 14) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 36, weight: .medium))
                    .accessibilityHidden(true)
                Text("Your truck stock is empty").font(.headline)
                Text("Add the parts you carry. Tap Used whenever one leaves the truck.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                GUPrimary("Add first item", icon: "plus", action: requestAdd)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }
}

private struct SummaryTile: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(color.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct StockItemCard: View {
    @Environment(\.guRuntime) private var runtime
    let item: InventoryItem
    let useAction: () -> Void
    let addAction: () -> Void
    let editAction: () -> Void

    private var low: Bool { InventoryRules.isLowStock(onHand: item.quantity, restockAt: item.restockAt) }

    var body: some View {
        let palette = runtime?.palette ?? GUPalettes.light
        GUSection {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name).font(.headline).lineLimit(2)
                    if !item.partNumber.isEmpty {
                        Text(item.partNumber).font(.subheadline.monospaced()).foregroundStyle(palette.secondary)
                    }
                    HStack(spacing: 8) {
                        Text(item.category.label)
                        if !item.location.isEmpty { Text("• \(item.location)") }
                    }
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text("\(item.quantity)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(item.quantity == 0 ? palette.error : low ? palette.warning : palette.text)
                    if item.quantity == 0 { GUStatus("Out", tone: "error") }
                    else if low { GUStatus("Low", tone: "warning") }
                }
            }

            HStack(spacing: 10) {
                Button(action: useAction) {
                    Text("Used").fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.quantity == 0)
                .accessibilityLabel("Use one \(item.name)")

                Button(action: addAction) {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add one \(item.name)")

                Button(action: editAction) {
                    Image(systemName: "pencil").frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Edit \(item.name)")
            }
        }
    }
}
