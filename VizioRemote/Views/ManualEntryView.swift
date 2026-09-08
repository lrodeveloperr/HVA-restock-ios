import SwiftUI

struct ManualEntryView: View {
    @ObservedObject var model: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var ipAddress = ""
    @State private var legacyPort = false
    @State private var confirmSecurityReset = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("TV address") {
                    TextField(text: $ipAddress, prompt: Text(verbatim: "192.168.1.25")) {
                        Text("TV address")
                    }
                        .keyboardType(.decimalPad)
                        .textContentType(.URL)
                        .focused($focused)
                    Toggle("Older firmware (port 9000)", isOn: $legacyPort)
                }

                Section {
                    Text("Find the TV address under Menu › Network › Network Information. Most current TVs use port 7345.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Connect") {
                    model.connectManually(ipAddress: ipAddress, legacyPort: legacyPort)
                }
                .disabled(ipAddress.trimmingCharacters(in: .whitespaces).isEmpty)

                Section("Security") {
                    Button("Reset Saved TV Identity", role: .destructive) {
                        confirmSecurityReset = true
                    }
                    .disabled(ipAddress.trimmingCharacters(in: .whitespaces).isEmpty || model.isManagingLocalData)
                    Text("Use this only after replacing or updating your TV when the app reports that its security identity changed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Enter IP Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
            .confirmationDialog(
                "Reset the saved identity for this address?",
                isPresented: $confirmSecurityReset,
                titleVisibility: .visible
            ) {
                Button("Reset TV Identity", role: .destructive) {
                    model.resetSecurityIdentity(ipAddress: ipAddress, legacyPort: legacyPort)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only continue if you replaced or updated this TV and trust the current local network.")
            }
        }
    }
}
