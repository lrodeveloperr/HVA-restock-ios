import SwiftUI

struct RemoteView: View {
    @ObservedObject var model: RemoteViewModel
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if case .trialActive(let end) = purchases.accessState {
                    trialBanner(endsAt: end)
                }
                Group {
                    quickActions
                    directionalPad
                    volumeAndChannel
                    mediaControls
                }
                .disabled(!model.canSendCommands)
                .opacity(model.canSendCommands ? 1 : 0.55)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func trialBanner(endsAt end: Date) -> some View {
        Button { purchases.showPurchaseSheet = true } label: {
            HStack {
                Label("1-day Trial", systemImage: "clock")
                Spacer()
                Text(end, style: .relative)
                Image(systemName: "chevron.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.remoteBlue.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityHint("View the one-time unlock")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.device?.name ?? String(localized: "Vizio TV"))
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(model.connectionState.label)
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            Spacer()
            Button { model.send(.power) } label: {
                Image(systemName: "power")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.red)
                    .background(Color.panelBackground, in: Circle())
            }
            .accessibilityLabel("Power")
            .accessibilityHint("The TV must be awake and reachable on Wi-Fi")
            .disabled(!model.canSendCommands)
            .opacity(model.canSendCommands ? 1 : 0.55)

            Button { model.showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(Color.panelBackground, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 12)
    }

    private var quickActions: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    quickActionButtons
                }
            } else {
                HStack(spacing: 10) {
                    quickActionButtons
                }
            }
        }
    }

    @ViewBuilder
    private var quickActionButtons: some View {
        CompactRemoteButton(title: String(localized: "Back"), symbol: "arrow.uturn.backward") { model.send(.back) }
        CompactRemoteButton(title: String(localized: "Home"), symbol: "house.fill") { model.send(.home) }
        CompactRemoteButton(title: String(localized: "Input"), symbol: "rectangle.on.rectangle") { model.send(.input) }
        CompactRemoteButton(title: String(localized: "Menu"), symbol: "list.bullet") { model.send(.menu) }
    }

    private var directionalPad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.panelBackground)
                .frame(width: 238, height: 238)

            RemoteIconButton(symbol: "chevron.up", label: String(localized: "Up")) { model.send(.up) }
                .offset(y: -78)
            RemoteIconButton(symbol: "chevron.left", label: String(localized: "Left")) { model.send(.left) }
                .offset(x: -78)

            Button { model.send(.select) } label: {
                Text("OK")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Color.remoteBlue, in: Circle())
            }
            .accessibilityLabel("OK")

            RemoteIconButton(symbol: "chevron.right", label: String(localized: "Right")) { model.send(.right) }
                .offset(x: 78)
            RemoteIconButton(symbol: "chevron.down", label: String(localized: "Down")) { model.send(.down) }
                .offset(y: 78)
        }
        .frame(height: 238)
    }

    private var volumeAndChannel: some View {
        HStack(spacing: 14) {
            VerticalControl(
                title: String(localized: "VOLUME"),
                topSymbol: "plus",
                bottomSymbol: "minus",
                topLabel: String(localized: "Volume up"),
                bottomLabel: String(localized: "Volume down"),
                topAction: { model.send(.volumeUp) },
                centerAction: { model.send(.mute) },
                bottomAction: { model.send(.volumeDown) }
            )

            Button { model.showTextEntry = true } label: {
                VStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 25, weight: .medium))
                    Text("Keyboard")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 142)
                .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 22))
            }
            .accessibilityHint(Text("Enter text using the on-screen keyboard"))

            VerticalControl(
                title: String(localized: "CHANNEL"),
                topSymbol: "chevron.up",
                bottomSymbol: "chevron.down",
                topLabel: String(localized: "Channel up"),
                bottomLabel: String(localized: "Channel down"),
                topAction: { model.send(.channelUp) },
                centerAction: nil,
                bottomAction: { model.send(.channelDown) }
            )
        }
    }

    private var mediaControls: some View {
        HStack(spacing: 12) {
            mediaButton(title: String(localized: "Play"), symbol: "play.fill", command: .play)
            mediaButton(title: String(localized: "Pause"), symbol: "pause.fill", command: .pause)
        }
    }

    private func mediaButton(title: String, symbol: String, command: RemoteCommand) -> some View {
        Button { model.send(command) } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 22))
        }
    }

    private var statusColor: Color {
        switch model.connectionState {
        case .connected, .sending: return .green
        case .failed: return .orange
        default: return .gray
        }
    }
}

private struct CompactRemoteButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct RemoteIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }
}

private struct VerticalControl: View {
    let title: String
    let topSymbol: String
    let bottomSymbol: String
    let topLabel: String
    let bottomLabel: String
    let topAction: () -> Void
    let centerAction: (() -> Void)?
    let bottomAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Color.secondaryText)
                .padding(.top, 12)

            Button(action: topAction) {
                Image(systemName: topSymbol)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityLabel(topLabel)

            if let centerAction {
                Button(action: centerAction) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.caption)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.09), in: Capsule())
                }
                .accessibilityLabel("Mute")
            } else {
                Divider().overlay(.white.opacity(0.12)).padding(.horizontal, 12)
            }

            Button(action: bottomAction) {
                Image(systemName: bottomSymbol)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityLabel(bottomLabel)
        }
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 82, height: 142)
        .background(Color.panelBackground, in: RoundedRectangle(cornerRadius: 22))
    }
}
