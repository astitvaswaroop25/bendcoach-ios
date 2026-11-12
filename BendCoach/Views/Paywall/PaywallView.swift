import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: ProStore
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64

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
                VStack(spacing: 24) {
                    header
                    featureList
                    purchaseArea
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
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

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .symbolRenderingMode(.palette)
                .font(.system(size: iconSize))
                .foregroundStyle(Theme.onHighVis, Theme.highVis)
                .accessibilityHidden(true)
            Text("BendCoach Pro")
                .font(.largeTitle.bold())
            Text("One purchase. No subscription.")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.self) { feature in
                Label(feature.title, systemImage: feature.symbol)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var purchaseArea: some View {
        VStack(spacing: 14) {
            switch store.status {
            case .loading:
                ProgressView("Checking the App Store…")
                    .frame(minHeight: 50)
            case .ready:
                Button {
                    Task { await store.purchase() }
                } label: {
                    if store.isPurchasing {
                        ProgressView().tint(Theme.onHighVis)
                    } else {
                        Text(buyTitle)
                    }
                }
                .buttonStyle(.highVisFullWidth)
                .disabled(store.isPurchasing)
            case .unavailable:
                unavailableMessage
            }

            if ProStore.offersTestUnlock && store.status != .ready {
                testUnlock
            }

            Button("Restore purchases") {
                Task { await store.restore() }
            }
            .font(.subheadline)
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var unavailableMessage: some View {
        VStack(spacing: 12) {
            Text("The App Store didn't answer. Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await store.refresh() }
            }
            .frame(minHeight: 44)
        }
    }

    /// Sideloaded and simulator builds can't reach the App Store, so they unlock Pro here.
    private var testUnlock: some View {
        VStack(spacing: 8) {
            Button("Unlock Pro for testing") {
                store.debugUnlock = true
            }
            .buttonStyle(.highVisFullWidth)
            Text("Test builds can't buy from the App Store, so this unlocks Pro on this device. App Store builds don't have this button.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var buyTitle: String {
        if let product = store.product {
            return "Unlock for \(product.displayPrice)"
        }
        if let price = Demo.storePrice {
            return "Unlock for \(price)"
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
