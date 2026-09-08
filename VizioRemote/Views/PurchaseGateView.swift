import SwiftUI

struct PurchaseGateView: View {
    @ObservedObject var purchases: PurchaseManager
    let model: RemoteViewModel?
    @Environment(\.locale) private var locale

    init(purchases: PurchaseManager, model: RemoteViewModel? = nil) {
        self.purchases = purchases
        self.model = model
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: isTVReadyForTrial ? "checkmark.circle.fill" : "tv.and.mediabox")
                        .font(.system(size: isTVReadyForTrial ? 48 : 54, weight: .medium))
                        .foregroundStyle(isTVReadyForTrial ? Color.green : Color.remoteBlue)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text(primaryTitle)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(headline)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label(firstBenefit, systemImage: "clock")
                        Label(secondBenefit, systemImage: "hand.raised")
                        Label("After 24 hours, buy once to keep control", systemImage: "checkmark.seal")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 18))

                    if purchases.accessState == .trialAvailable {
                        Button {
                            Task { await purchases.startTrial() }
                        } label: {
                            Text(trialButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(
                            purchases.isWorking || purchases.isLoadingProducts ||
                            (!hasScreenshotPriceOverrides &&
                             (purchases.trialProduct == nil || purchases.lifetimeProduct == nil))
                        )
                    }

                    if purchases.canBuyLifetime {
                        Button {
                            Task { await purchases.buyLifetime() }
                        } label: {
                            Text(lifetimeButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryPurchaseButtonStyle())
                        .disabled(
                            purchases.isWorking || purchases.isLoadingProducts ||
                            (!hasScreenshotPriceOverrides && purchases.lifetimeProduct == nil)
                        )
                    }

                    if purchases.isWorking || purchases.isLoadingProducts {
                        ProgressView("Contacting the App Store…")
                            .tint(.white)
                    }

                    Text(disclosure)
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)

                    Button("Restore Purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                    .disabled(purchases.isWorking || purchases.isLoadingProducts)

                    if (purchases.trialProduct == nil || purchases.lifetimeProduct == nil) &&
                        !hasScreenshotPriceOverrides {
                        Button("Retry App Store") {
                            Task { await purchases.loadProducts() }
                        }
                        .disabled(purchases.isWorking || purchases.isLoadingProducts)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) {
                            purchaseLegalLinks
                        }
                        VStack(spacing: 12) {
                            purchaseLegalLinks
                        }
                    }
                    .font(.footnote.weight(.medium))

                    if let model {
                        NavigationLink("Manage Saved TV Data") {
                            LocalDataManagementView(model: model)
                        }
                        .font(.footnote.weight(.medium))
                    }

                    Text("Independent and not affiliated with or endorsed by Vizio, Inc.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
            .background(Color.appBackground.ignoresSafeArea())
        }
        .alert(
            "App Store",
            isPresented: Binding(
                get: { purchases.errorMessage != nil },
                set: { if !$0 { purchases.errorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) { purchases.errorMessage = nil } },
            message: { Text(purchases.errorMessage ?? "") }
        )
    }

    @ViewBuilder private var purchaseLegalLinks: some View {
        Link("Privacy", destination: AppLegalLinks.privacy(for: locale))
        Link("Terms", destination: AppLegalLinks.terms(for: locale))
        Link("Purchase Terms", destination: AppLegalLinks.purchases)
        Link("Support", destination: AppLegalLinks.support)
    }

    private var isTVReadyForTrial: Bool {
        purchases.accessState == .trialAvailable &&
            model?.device != nil &&
            model?.device?.isDemo == false
    }

    private var primaryTitle: String {
        isTVReadyForTrial
            ? String(localized: "Your TV is ready")
            : String(localized: "Remote for Vizio TV Controller")
    }

    private var firstBenefit: String {
        isTVReadyForTrial
            ? String(localized: "Full remote access for 24 hours")
            : String(localized: "Use all included remote controls for 24 hours")
    }

    private var secondBenefit: String {
        isTVReadyForTrial
            ? String(localized: "No app account, subscription or automatic charge")
            : String(localized: "No ads and no separate app account")
    }

    private var headline: String {
        if isTVReadyForTrial {
            return String(localized: "Start your free 24-hour trial")
        }
        switch purchases.accessState {
        case .trialExpired:
            return String(localized: "Your 1-day trial has ended")
        case .trialActive:
            return String(localized: "Your 1-day trial is active")
        case .verificationFailed:
            return String(localized: "Purchase verification needed")
        default:
            return String(localized: "Try every feature for one day")
        }
    }

    private var trialButtonTitle: String {
        let format = String(localized: "Start Free 24-Hour Trial · %@")
        return String(format: format, trialDisplayPrice)
    }

    private var lifetimeButtonTitle: String {
        let format = String(localized: "Full Remote Unlock · %@")
        return String(format: format, lifetimeDisplayPrice)
    }

    private var trialDisplayPrice: String {
#if DEBUG
        if let price = ProcessInfo.processInfo.environment["SCREENSHOT_TRIAL_PRICE"] {
            return price
        }
#endif
        return purchases.trialProduct?.displayPrice ?? "—"
    }

    private var lifetimeDisplayPrice: String {
#if DEBUG
        if let price = ProcessInfo.processInfo.environment["SCREENSHOT_LIFETIME_PRICE"] {
            return price
        }
#endif
        return purchases.lifetimeProduct?.displayPrice ?? "—"
    }

    private var hasScreenshotPriceOverrides: Bool {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["SCREENSHOT_TRIAL_PRICE"] != nil &&
            environment["SCREENSHOT_LIFETIME_PRICE"] != nil
#else
        return false
#endif
    }

    private var disclosure: String {
        if purchases.accessState == .trialExpired {
            return String(localized: "Remote control access stopped when the 24-hour trial ended. The trial does not renew and made no automatic charge. Buy the one-time unlock to restore full access.")
        }
        if purchases.accessState == .verificationFailed {
            if purchases.lifetimeVerificationFailed {
                return String(localized: "Your full unlock could not be verified. Remote access remains locked. Use Restore Purchases or contact Apple Support; do not buy it again.")
            }
            return String(localized: "An App Store purchase could not be verified, so remote access remains locked. Try Restore Purchases or contact Apple Support. No new purchase is required until verification is resolved.")
        }
        if let trialEnd = purchases.trialEnd {
            let format = String(localized: "Trial access ends %@. It does not renew and you will not be charged automatically. The optional one-time unlock costs %@.")
            return String(
                format: format,
                trialEnd.formatted(date: .abbreviated, time: .shortened),
                lifetimeDisplayPrice
            )
        }
        let format = String(localized: "The free 1-day Trial unlocks all remote features for 24 hours. Remote control access stops when it ends. It does not renew and you will not be charged automatically. Afterward, the optional one-time unlock costs %@.")
        return String(format: format, lifetimeDisplayPrice)
    }
}

private struct LocalDataManagementView: View {
    @ObservedObject var model: RemoteViewModel
    @State private var ipAddress = ""
    @State private var legacyPort = false
    @State private var confirmForget = false
    @State private var confirmReset = false
    @State private var confirmRemoveAll = false

    var body: some View {
        Form {
            Section {
                if let device = model.device {
                    LabeledContent("Name", value: device.name)
                    LabeledContent("Address", value: device.isDemo ? String(localized: "Demo mode") : "\(device.host):\(device.port)")
                    Button("Forget This TV", role: .destructive) { confirmForget = true }
                        .disabled(model.isManagingLocalData)
                } else {
                    Text("No saved TV is currently available.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Saved TV")
            } footer: {
                Text("Remote controls remain locked. Forget removes the saved address, pairing token and TV certificate identity from this device.")
            }

            Section {
                TextField(text: $ipAddress, prompt: Text(verbatim: "192.168.1.25")) {
                    Text("TV address")
                }
                    .keyboardType(.decimalPad)
                    .textContentType(.URL)
                Toggle("Older firmware (port 9000)", isOn: $legacyPort)
                Button("Reset Saved TV Identity", role: .destructive) { confirmReset = true }
                    .disabled(ipAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isManagingLocalData)
                Button("Remove All Saved TV Data", role: .destructive) { confirmRemoveAll = true }
                    .disabled(model.isManagingLocalData)
            } header: {
                Text("Reset TV Security Identity")
            } footer: {
                Text("Use identity reset only after replacing or updating a TV when the app reports that its security identity changed.")
            }
        }
        .navigationTitle("Manage Local Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let device = model.device, !device.isDemo else { return }
            ipAddress = device.host
            legacyPort = device.port == 9000
        }
        .confirmationDialog("Forget this TV?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Forget TV", role: .destructive) { model.forgetTV() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Reset the saved identity for this address?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset TV Identity", role: .destructive) {
                model.resetSecurityIdentity(ipAddress: ipAddress, legacyPort: legacyPort)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only continue if you replaced or updated this TV and trust the current local network.")
        }
        .confirmationDialog("Remove all saved TV data?", isPresented: $confirmRemoveAll, titleVisibility: .visible) {
            Button("Remove All TV Data", role: .destructive) { model.removeAllSavedTVData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved TV address, pairing token, certificate identity and app-generated TV client identifier from this device.")
        }
    }
}

private struct SecondaryPurchaseButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                Color.panelBackground.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.18)))
            .opacity(isEnabled ? 1 : 0.45)
    }
}
