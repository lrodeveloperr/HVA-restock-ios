import SwiftUI

struct LifetimeUnlockView: View {
    @Environment(\.dismiss) private var dismiss
    let purchase: PurchaseManager

    var body: some View {
        NavigationStack {
            GoodUseFrame { runtime in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Unlimited truck stock")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(runtime.palette.text)
                        Text("Keep every part you carry in one private, offline restock list.")
                            .font(.system(size: 17))
                            .foregroundStyle(runtime.palette.secondary)

                        GUSection {
                            feature("Unlimited items", icon: "shippingbox")
                            feature("Automatic restock list", icon: "cart")
                            feature("Reversible activity history", icon: "clock.arrow.circlepath")
                            feature("CSV import and export", icon: "tablecells")
                        }

                        GUSection(emphasis: true) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Lifetime access").font(.headline)
                                    Text("One payment. No subscription.")
                                        .font(.subheadline)
                                        .foregroundStyle(runtime.palette.secondary)
                                }
                                Spacer()
                                Text(purchase.priceText).font(.title2.bold())
                            }
                        }

                        GUPrimary(purchase.isBusy ? "Please wait…" : "Unlock for \(purchase.priceText)") {
                            Task { await purchase.purchase() }
                        }
                        .disabled(!purchase.canPurchase)

                        Button("Restore purchase") {
                            Task { await purchase.restore() }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(purchase.isBusy)

                        if let message = purchase.message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(purchase.isUnlocked ? runtime.palette.success : runtime.palette.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        Text("Your existing records remain available whether or not you unlock unlimited items.")
                            .font(.footnote)
                            .foregroundStyle(runtime.palette.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle("Lifetime unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: purchase.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }

    private func feature(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }
}
