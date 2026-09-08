import SwiftUI

struct PairingView: View {
    @ObservedObject var model: RemoteViewModel
    @State private var pin = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "rectangle.connected.to.line.below")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.remoteBlue)

                    VStack(spacing: 8) {
                        Text("Enter the TV PIN")
                            .font(.title2.bold())
                        Text(model.pairingIsDemo
                             ? String(localized: "Use 1234 to pair with the Demo TV.")
                             : String(localized: "A four-digit code should now be visible on your TV."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if !model.pairingIsDemo {
                        Label(
                            "Only continue on a private Wi-Fi network you trust. This first pairing saves the selected TV’s security identity on this device.",
                            systemImage: "lock.shield"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    }

                    TextField(text: $pin, prompt: Text(verbatim: "0000")) {
                        Text("PIN")
                    }
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                    .onChange(of: pin) { _, value in
                        let digits = value.unicodeScalars.filter { (48...57).contains($0.value) }
                        pin = String(String.UnicodeScalarView(digits).prefix(4))
                    }

                    Button("Pair TV") { model.finishPairing(pin: pin) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(pin.count != 4 || model.isCompletingPairing)
                }
                .frame(maxWidth: 520)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancelPairing() }
                        .disabled(model.isCompletingPairing)
                }
            }
            .onAppear { focused = true }
        }
    }
}
