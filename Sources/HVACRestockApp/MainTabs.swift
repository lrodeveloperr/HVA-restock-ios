import SwiftUI
import UniformTypeIdentifiers
import HVACRestockCore

private enum AppTab: Hashable {
    case stock
    case restock
    case activity
}

struct MainTabs: View {
    let store: InventoryStore
    let purchase: PurchaseManager
    @Binding var initialAction: InitialAction

    @State private var selectedTab: AppTab = .stock
    @State private var showSettings = false
    @State private var showAddItem = false
    @State private var showImporter = false
    @State private var showPaywall = false
    @State private var pendingImport = false
    @State private var importPreview: CSVImportPreview?
    @State private var importError: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                StockScreen(store: store, purchase: purchase, requestAdd: requestAdd)
                    .standardToolbar(showSettings: $showSettings)
            }
            .tabItem { Label("Stock", systemImage: "shippingbox") }
            .tag(AppTab.stock)

            NavigationStack {
                RestockScreen(store: store)
                    .standardToolbar(showSettings: $showSettings)
            }
            .tabItem { Label("Restock", systemImage: "cart") }
            .badge(store.lowStockItems.count)
            .tag(AppTab.restock)

            NavigationStack {
                ActivityScreen(store: store)
                    .standardToolbar(showSettings: $showSettings)
            }
            .tabItem { Label("Activity", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.activity)
        }
        .tint(GUPalettes.light.primary)
        .sheet(isPresented: $showSettings) {
            SettingsScreen(store: store, purchase: purchase, requestImport: {
                pendingImport = true
                showSettings = false
            })
        }
        .sheet(isPresented: $showAddItem) {
            ItemEditor(title: "Add item", initial: InventoryDraft()) { draft in
                try store.add(draft, unlocked: purchase.isUnlocked)
            }
        }
        .sheet(isPresented: $showPaywall) {
            LifetimeUnlockView(purchase: purchase)
        }
        .sheet(item: $importPreview) { preview in
            CSVImportReview(
                preview: preview,
                store: store,
                purchase: purchase
            )
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "The file could not be imported.")
        }
        .task { handleInitialAction() }
        .onChange(of: initialAction) { _, _ in handleInitialAction() }
        .onChange(of: showSettings) { _, isPresented in
            guard !isPresented, pendingImport else { return }
            pendingImport = false
            showImporter = true
        }
    }

    private func requestAdd() {
        if purchase.isUnlocked || store.activeItemCount < InventoryRules.freeItemLimit {
            showAddItem = true
        } else {
            showPaywall = true
        }
    }

    private func handleInitialAction() {
        switch initialAction {
        case .none: break
        case .add:
            selectedTab = .stock
            requestAdd()
        case .importCSV:
            showImporter = true
        }
        initialAction = .none
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = values.fileSize, fileSize > InventoryCSVCodec.maximumImportBytes {
                throw CSVCodecError.fileTooLarge
            }
            let data = try readImportData(from: url)
            importPreview = try InventoryCSVCodec.preview(data: data)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func readImportData(from url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var data = Data()
        while data.count <= InventoryCSVCodec.maximumImportBytes {
            let remaining = InventoryCSVCodec.maximumImportBytes + 1 - data.count
            guard let chunk = try handle.read(upToCount: min(64 * 1_024, remaining)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count <= InventoryCSVCodec.maximumImportBytes else { throw CSVCodecError.fileTooLarge }
        return data
    }
}

private extension View {
    func standardToolbar(showSettings: Binding<Bool>) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings.wrappedValue = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Settings")
            }
        }
    }
}
