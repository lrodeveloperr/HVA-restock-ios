import SwiftUI

struct ConnectionView: View {
    @ObservedObject var model: RemoteViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 12)

                Image(systemName: "tv.and.mediabox")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(Color.remoteBlue)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Remote for Vizio TV Controller")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Text("A simple remote for Vizio SmartCast TVs")
                        .font(.body)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 16) {
                    requirementRow("This device and TV on the same Wi-Fi", systemImage: "wifi")
                    requirementRow("Compatible Vizio SmartCast televisions", systemImage: "checkmark.seal")
                    requirementRow("24-hour trial · no app account needed", systemImage: "clock")
                    requirementRow("After 24 hours, buy once to keep control", systemImage: "lock.open")
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

                Button(action: model.useDemoTV) {
                    Label("Try Demo TV", systemImage: "play.rectangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
                .disabled(model.isBusy)

                Text("Try the demo instantly. Your real-TV trial starts only after you confirm.")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)

                Text("Remote for Vizio TV Controller is an independent app and is not affiliated with or endorsed by Vizio, Inc.")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func requirementRow(
        _ title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
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

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .background(
                Color.panelBackground.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.16))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.45)
    }
}
