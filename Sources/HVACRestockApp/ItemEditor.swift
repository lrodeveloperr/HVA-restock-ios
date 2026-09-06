import SwiftUI
import HVACRestockCore

struct ItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let save: (InventoryDraft) throws -> Void
    let delete: (() throws -> Void)?

    @State private var draft: InventoryDraft
    @State private var errorMessage: String?
    @State private var confirmDelete = false

    init(
        title: String,
        initial: InventoryDraft,
        save: @escaping (InventoryDraft) throws -> Void,
        delete: (() throws -> Void)? = nil
    ) {
        self.title = title
        self.save = save
        self.delete = delete
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                    TextField("Part number (optional)", text: $draft.partNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Picker("Category", selection: $draft.category) {
                        ForEach(InventoryCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    TextField("Truck location (optional)", text: $draft.location)
                        .textInputAutocapitalization(.words)
                }

                Section("Quantities") {
                    QuantityField(label: "On truck", value: $draft.quantity, minimum: 0)
                    QuantityField(label: "Restock at", value: $draft.restockAt, minimum: 0)
                    QuantityField(label: "Restock to", value: $draft.restockTo, minimum: 1)
                    if draft.restockTo <= draft.restockAt {
                        Text("Restock to must be greater than Restock at.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if delete != nil {
                    Section {
                        Button("Delete item", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .fontWeight(.semibold)
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.restockTo <= draft.restockAt)
                }
            }
            .alert("Couldn’t save item", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Try again.")
            }
            .confirmationDialog("Delete this item? Activity history will remain available.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { remove() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func submit() {
        do {
            try save(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove() {
        guard let delete else { return }
        do {
            try delete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct QuantityField: View {
    let label: String
    @Binding var value: Int
    let minimum: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                value = max(minimum, value - 1)
            } label: {
                Image(systemName: "minus").frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .disabled(value <= minimum)
            .accessibilityLabel("Decrease \(label)")

            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 64)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)

            Button {
                value = min(InventoryRules.maximumQuantity, value + 1)
            } label: {
                Image(systemName: "plus").frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .disabled(value >= InventoryRules.maximumQuantity)
            .accessibilityLabel("Increase \(label)")
        }
    }
}
