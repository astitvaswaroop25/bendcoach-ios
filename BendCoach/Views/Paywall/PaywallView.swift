import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: ProStore
    @Environment(\.dismiss) private var dismiss

    private struct Feature: Hashable {
        let title: String
        let symbol: String
    }

    private let features: [Feature] = [
        Feature(title: "3-point and 4-point saddles", symbol: "triangle"),
        Feature(title: "Back-to-back 90s", symbol: "arrow.uturn.up"),
        Feature(title: "Rolling offsets", symbol: "rotate.3d"),
        Feature(title: "Unlimited calibrated benders", symbol: "wrench.adjustable"),
        Feature(title: "Unlimited saved bends", symbol: "tray.full")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)
                    Text("BendCoach Pro")
                        .font(.largeTitle.bold())
                    Text("One purchase. No subscription.")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.self) { feature in
                            Label(feature.title, systemImage: feature.symbol)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        Task { await store.purchase() }
                    } label: {
                        Group {
                            if store.isPurchasing {
                                ProgressView()
                            } else {
                                Text(buyTitle).bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isPurchasing || store.product == nil)

                    if store.product == nil {
                        Text("Connecting to the App Store…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                    .font(.subheadline)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Purchase problem", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
            .task {
                if store.product == nil {
                    await store.refresh()
                }
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private var buyTitle: String {
        if let product = store.product {
            return "Unlock for \(product.displayPrice)"
        }
        return "Unlock Pro"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isShowing in
                if !isShowing { store.errorMessage = nil }
            }
        )
    }
}
