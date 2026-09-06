import SwiftUI
import SwiftData
import HVACRestockApp

@main
struct HVACRestockApp: App {
    var body: some Scene {
        WindowGroup {
            HVACRestockRoot()
        }
        .modelContainer(for: [InventoryItem.self, StockEvent.self])
    }
}
