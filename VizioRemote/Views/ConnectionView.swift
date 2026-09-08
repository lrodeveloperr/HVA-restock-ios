import SwiftUI

struct ConnectionView: View {
    @ObservedObject var model: RemoteViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 28)

                Image(systemName: "tv.and.mediabox")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(Color.remoteBlue)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("ClearMote: Remote for Vizio")
                        .font(.largeTitle.bold())
                    Text("A simple remote for Vizio SmartCast TVs")
                        .font(.body)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    Label("This device and TV on the same Wi-Fi", systemImage: "wifi")
                    Label("Compatible Vizio SmartCast televisions", systemImage: "checkmark.seal")
                    Label("1-day trial · Optional one-time unlock · No ads", systemImage: "hand.raised")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 20))

                Button(action: model.discover) {
                    HStack {
                        if model.connectionState == .searching {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(model.connectionState == .searching
                             ? String(localized: "Searching…")
                             : String(localized: "Find My TV"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.isBusy)

                if !model.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FOUND ON YOUR NETWORK")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondaryText)

                        ForEach(model.discoveredDevices) { device in
                            Button { model.beginPairing(with: device) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "tv")
                                        .foregroundStyle(Color.remoteBlue)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(device.name).foregroundStyle(.white)
                                        Text(device.host).font(.caption).foregroundStyle(Color.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Color.secondaryText)
                                }
                                .padding(16)
                                .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        Button("Enter IP Address") { model.showManualEntry = true }
                        Text(verbatim: "·").foregroundStyle(Color.secondaryText)
                        Button("Try Demo TV") { model.useDemoTV() }
                    }
                    VStack(spacing: 12) {
                        Button("Enter IP Address") { model.showManualEntry = true }
                        Button("Try Demo TV") { model.useDemoTV() }
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.remoteBlue)

                Text("ClearMote: Remote for Vizio is an independent app and is not affiliated with or endorsed by Vizio, Inc.")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                Color.remoteBlue.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.45)
    }
}
