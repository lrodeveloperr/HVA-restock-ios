import SwiftUI

@main
struct VizioRemoteApp: App {
    @StateObject private var model = RemoteViewModel()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootView(model: model, purchases: purchases)
                .preferredColorScheme(.dark)
        }
    }
}
