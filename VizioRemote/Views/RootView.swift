import SwiftUI

struct RootView: View {
    @ObservedObject var model: RemoteViewModel
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            switch purchases.accessState {
            case .loading:
                if model.device?.isDemo == true {
                    RemoteView(model: model, purchases: purchases)
                } else {
                    ConnectionView(model: model)
                }
            case .trialActive, .lifetimeUnlocked:
                if model.hasSavedTV {
                    RemoteView(model: model, purchases: purchases)
                } else {
                    ConnectionView(model: model)
                }
            case .trialAvailable:
                if model.device?.isDemo == true {
                    RemoteView(model: model, purchases: purchases)
                } else if model.hasSavedTV {
                    PurchaseGateView(purchases: purchases, model: model)
                } else {
                    ConnectionView(model: model)
                }
            case .trialExpired, .verificationFailed:
                PurchaseGateView(purchases: purchases, model: model)
            }
        }
        .task {
            model.restoreLocalDeviceMetadata()
            await purchases.prepare()
            reconcileAccess()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await purchases.prepare()
                    reconcileAccess()
                }
            } else if phase == .background {
                model.setRemoteAccessEnabled(false)
            }
        }
        .onChange(of: purchases.hasRemoteAccess) { _, _ in
            reconcileAccess()
        }
        .onChange(of: model.device) { _, _ in
            reconcileAccess()
        }
        .sheet(isPresented: $model.showManualEntry) {
            ManualEntryView(model: model)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model, purchases: purchases)
        }
        .sheet(isPresented: $model.showTextEntry) {
            TextEntryView(model: model)
                .presentationDetents([.medium, .large])
        }
        .sheet(
            isPresented: Binding(
                get: { model.pairingChallenge != nil },
                set: { if !$0 { model.cancelPairing() } }
            )
        ) {
            PairingView(model: model)
                .interactiveDismissDisabled(model.isCompletingPairing)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $purchases.showPurchaseSheet) {
            PurchaseGateView(purchases: purchases, model: model)
        }
        .alert(
            "TV Remote",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) { model.alertMessage = nil } },
            message: { Text(model.alertMessage ?? "") }
        )
    }

    private func reconcileAccess() {
        model.restoreLocalDeviceMetadata()
        let demoAccess = (purchases.accessState == .loading || purchases.accessState == .trialAvailable) &&
            model.device?.isDemo == true
        let enabled = scenePhase == .active && (purchases.hasRemoteAccess || demoAccess)
        model.setRemoteAccessEnabled(enabled)
        if enabled {
            model.restore()
            model.resume()
        }
    }
}

extension Color {
    static let appBackground = Color(red: 0.035, green: 0.047, blue: 0.071)
    static let panelBackground = Color(red: 0.075, green: 0.094, blue: 0.133)
    static let remoteBlue = Color(red: 0.0, green: 0.36, blue: 0.72)
    static let secondaryText = Color.white.opacity(0.62)
}
