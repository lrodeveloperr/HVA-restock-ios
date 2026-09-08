import SwiftUI

struct TextEntryView: View {
    @ObservedObject var model: RemoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TextField("Type on your TV", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .padding(14)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                    Text("Text entry accepts up to 128 basic Latin characters and works only when the TV displays an editable field.")
                        .font(.footnote)
                        .foregroundStyle(isSupportedText || text.isEmpty ? Color.secondary : Color.red)

                    Button("Send to TV") { model.sendText(text) }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isSupportedText)
                }
                .padding(20)
            }
            .navigationTitle("TV Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }

    private var isSupportedText: Bool {
        let scalars = text.unicodeScalars
        return !scalars.isEmpty && scalars.count <= 128 && scalars.allSatisfy { (32...126).contains($0.value) }
    }
}
