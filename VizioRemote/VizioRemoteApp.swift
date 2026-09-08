import SwiftUI

@main
struct VizioRemoteApp: App {
    @StateObject private var model: RemoteViewModel
    @StateObject private var purchases: PurchaseManager
#if DEBUG
    private let screenshotMode: String?
    private let isUnitTestHost: Bool
#endif

    init() {
        let model = RemoteViewModel()
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let screenshotMode = environment["SCREENSHOT_MODE"]
        let isUnitTestHost = environment["XCTestConfigurationFilePath"] != nil
        let purchases = PurchaseManager(
            listenForTransactions: screenshotMode == nil && !isUnitTestHost
        )
        if screenshotMode == "remote" {
            model.configureForScreenshotRemote()
            purchases.configureForScreenshot(
                accessState: .trialActive(endsAt: Date().addingTimeInterval(23 * 60 * 60))
            )
        } else if screenshotMode == "purchase" {
            purchases.configureForScreenshot(accessState: .trialAvailable)
        }
        self.screenshotMode = screenshotMode
        self.isUnitTestHost = isUnitTestHost
#else
        let purchases = PurchaseManager()
#endif
        _model = StateObject(wrappedValue: model)
        _purchases = StateObject(wrappedValue: purchases)
    }

    var body: some Scene {
        WindowGroup {
            content
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var content: some View {
#if DEBUG
        if isUnitTestHost {
            Color.appBackground.ignoresSafeArea()
        } else if screenshotMode == "connection" {
            screenshotContainer { ConnectionView(model: model) }
        } else if screenshotMode == "remote" {
            screenshotContainer { RemoteView(model: model, purchases: purchases) }
        } else if screenshotMode == "purchase" {
            screenshotContainer { PurchaseGateView(purchases: purchases, model: model) }
        } else {
            RootView(model: model, purchases: purchases)
        }
#else
        RootView(model: model, purchases: purchases)
#endif
    }

#if DEBUG
    private func screenshotContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            content()
        }
    }
#endif

}
