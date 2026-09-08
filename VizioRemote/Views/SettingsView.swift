import SwiftUI

enum AppLegalLinks {
    private static let baseURL = "https://lrodeveloperr.github.io/privacy-policy/tv-remote-control"

    static func privacy(for locale: Locale) -> URL {
        documentURL(named: "privacy", locale: locale)
    }

    static func terms(for locale: Locale) -> URL {
        documentURL(named: "terms", locale: locale)
    }

    static let purchases = URL(string: "\(baseURL)/purchases/")!
    static let support = URL(string: "https://worksbienstudios.com/customerservice")!

    private static func documentURL(named document: String, locale: Locale) -> URL {
        let identifier = locale.identifier.lowercased()
        let languagePath: String
        if identifier.hasPrefix("es") {
            languagePath = "es/"
        } else if identifier.hasPrefix("fr") {
            languagePath = "fr-ca/"
        } else {
            languagePath = ""
        }
        return URL(string: "\(baseURL)/\(languagePath)\(document)/")!
    }
}

struct SettingsView: View {
    @ObservedObject var model: RemoteViewModel
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @AppStorage("haptics.enabled") private var hapticsEnabled = true
    @State private var confirmForget = false
    @State private var confirmRemoveAll = false

    var body: some View {
        NavigationStack {
            List {
                Section("Connected TV") {
                    LabeledContent("Name", value: model.device?.name ?? "—")
                    LabeledContent("Address", value: model.device?.isDemo == true ? String(localized: "Demo mode") : model.device?.host ?? "—")
                    Button("Test Connection") { model.reconnect() }
                        .disabled(!model.canReconnect)
                }

                Section("Remote") {
                    Toggle("Button haptics", isOn: $hapticsEnabled)
                }

                Section("Access") {
                    LabeledContent("Status", value: accessLabel)
                    if purchases.accessState != .lifetimeUnlocked {
                        Button("Full Remote Unlock") {
                            dismiss()
                            Task { @MainActor in
                                await Task.yield()
                                purchases.showPurchaseSheet = true
                            }
                        }
                    }
                    Button("Restore Purchases") {
                        Task { await purchases.restorePurchases() }
                    }
                    .disabled(purchases.isWorking)
                }

                Section("Compatibility") {
                    Label("Compatible Vizio SmartCast televisions", systemImage: "tv")
                    Label("Same Wi-Fi network required", systemImage: "wifi")
                    Text("Power-on may be unavailable when the TV uses Eco Mode. Quick Start mode keeps network control available while the display is off.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    NavigationLink("Privacy Summary") {
                        PrivacySummaryView()
                    }
                    NavigationLink("Terms of Use") {
                        TermsSummaryView()
                    }
                    Link("Full Privacy Policy", destination: AppLegalLinks.privacy(for: locale))
                    Link("Supplemental Terms", destination: AppLegalLinks.terms(for: locale))
                    Link("Trial and Purchase Terms", destination: AppLegalLinks.purchases)
                    Link("Customer Support", destination: AppLegalLinks.support)
                }

                Section {
                    Button("Forget This TV", role: .destructive) { confirmForget = true }
                        .disabled(model.isManagingLocalData)
                    Button("Remove All Saved TV Data", role: .destructive) { confirmRemoveAll = true }
                        .disabled(model.isManagingLocalData)
                } footer: {
                    Text("This removes the saved address, secure pairing token and saved TV security identity from this device.")
                }

                Section {
                    Text(versionSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityHint("Close Settings")
                }
            }
            .confirmationDialog(
                "Forget this TV?",
                isPresented: $confirmForget,
                titleVisibility: .visible
            ) {
                Button("Forget TV", role: .destructive) { model.forgetTV() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Remove all saved TV data?", isPresented: $confirmRemoveAll, titleVisibility: .visible) {
                Button("Remove All TV Data", role: .destructive) { model.removeAllSavedTVData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every saved TV address, pairing token, certificate identity and app-generated TV client identifier from this device.")
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
    }

    private var accessLabel: String {
        switch purchases.accessState {
        case .loading: return String(localized: "Checking…")
        case .trialAvailable: return String(localized: "24-hour trial available")
        case .trialActive(let end):
            let format = String(localized: "Trial ends %@")
            return String(format: format, end.formatted(date: .abbreviated, time: .shortened))
        case .trialExpired: return String(localized: "Trial ended")
        case .verificationFailed: return String(localized: "Purchase verification needed")
        case .lifetimeUnlocked: return String(localized: "Full remote unlocked")
        }
    }

    private var versionSummary: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let format = String(localized: "Remote for Vizio TV Controller %@ (%@)\nFree 1-day trial. Optional one-time unlock.\nNo ads or subscriptions. Independent and not affiliated with Vizio, Inc.")
        return String(format: format, version, build)
    }
}

struct PrivacySummaryView: View {
    var body: some View {
        List {
            Section {
                Text("Remote for Vizio TV Controller does not collect, transmit, sell or share personal data with WorksBien Studios. It contains no advertising or analytics SDKs.")
            }
            Section("Stored on this device") {
                Text("The selected TV address, display name, pairing token and TV certificate identity are stored in the iOS Keychain and marked device-only. The app-generated TV client identifier and haptic preference are stored in local preferences.")
            }
            Section("Local network") {
                Text("Commands travel directly between this device and the selected television on the local network. WorksBien Studios does not receive them.")
            }
            Section("Purchases") {
                Text("Apple processes the free trial and one-time purchase. The app reads verified StoreKit transaction status and dates to decide whether remote access is available. WorksBien Studios does not receive your payment details.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsSummaryView: View {
    var body: some View {
        List {
            Section("Trial") {
                Text("The free 1-day Trial begins when its App Store purchase completes and provides all remote-control features for 24 hours. Access stops at the end of that period. The trial does not renew and does not charge you automatically.")
            }
            Section("Full Remote Unlock") {
                Text("The full remote unlock is a one-time, non-consumable in-app purchase. The entitlement does not expire, but TV and firmware compatibility can change. Its price is shown by the App Store before you confirm. Restore Purchases recovers an eligible purchase for the same Apple Account.")
            }
            Section("Compatibility") {
                Text("A supported Vizio SmartCast television and a working local Wi-Fi network are required for real TV control. Compatibility and network availability are not guaranteed for every model or setup.")
            }
            Section("Terms") {
                Link("Apple Standard Licensed Application End User License Agreement", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
}
