import SwiftUI

struct ActivityScreen: View {
    let store: InventoryStore

    @State private var eventToReverse: StockEvent?
    @State private var errorMessage: String?

    var body: some View {
        GoodUseFrame { runtime in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if store.events.isEmpty {
                        GUSection {
                            VStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 36))
                                    .foregroundStyle(runtime.palette.secondary)
                                    .accessibilityHidden(true)
                                Text("No activity yet").font(.headline)
                                Text("Stock changes will appear here.")
                                    .font(.subheadline)
                                    .foregroundStyle(runtime.palette.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        HStack {
                            Text("Newest first").font(.subheadline).foregroundStyle(runtime.palette.secondary)
                            Spacer()
                            ShareLink(
                                item: CSVShareFile(text: store.activityCSV(), filename: "HVAC-Stock-Activity.csv"),
                                preview: SharePreview("HVAC stock activity")
                            ) {
                                Label("CSV", systemImage: "square.and.arrow.up")
                                    .frame(minHeight: 44)
                            }
                        }
                        ForEach(store.events) { event in
                            ActivityCard(
                                event: event,
                                reversalAvailable: store.canReverse(event),
                                reverseAction: { eventToReverse = event }
                            )
                        }
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Activity")
        .confirmationDialog(
            "Reverse this stock change?",
            isPresented: Binding(
                get: { eventToReverse != nil },
                set: { if !$0 { eventToReverse = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Reverse") {
                guard let eventToReverse else { return }
                do { try store.reverse(eventToReverse) }
                catch { errorMessage = error.localizedDescription }
                self.eventToReverse = nil
            }
            Button("Cancel", role: .cancel) { eventToReverse = nil }
        } message: {
            if let eventToReverse {
                Text("\(eventToReverse.itemName): \(signed(eventToReverse.delta))")
            }
        }
        .alert("Couldn’t reverse change", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : String(value) }
}

private struct ActivityCard: View {
    @Environment(\.guRuntime) private var runtime
    let event: StockEvent
    let reversalAvailable: Bool
    let reverseAction: () -> Void

    var body: some View {
        let palette = runtime?.palette ?? GUPalettes.light
        GUSection {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.itemName).font(.headline)
                    Text(event.kind.label)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondary)
                    Text(event.createdAt, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(event.delta > 0 ? "+\(event.delta)" : String(event.delta))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(event.delta < 0 ? palette.warning : palette.success)
                    Text("Balance \(event.resultingQuantity)")
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                }
            }
            if reversalAvailable {
                Button("Reverse", action: reverseAction)
                    .frame(minHeight: 44)
            } else if event.reversedAt != nil {
                GUStatus("Reversed")
            } else if event.canReverse {
                GUStatus("Unavailable")
            }
        }
    }
}
