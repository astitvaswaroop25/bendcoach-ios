import SwiftUI
import BendKit

struct HomeView: View {
    @EnvironmentObject private var store: ProStore
    @Environment(\.currentBender) private var bender
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Your bender") {
                    NavigationLink {
                        BenderListView()
                    } label: {
                        BenderSummaryLabel(bender: bender)
                    }
                }

                Section("Bends") {
                    ForEach(BendKind.allCases) { kind in
                        if kind.requiresPro && !store.isPro {
                            Button {
                                showPaywall = true
                            } label: {
                                BendKindRow(kind: kind, locked: true)
                            }
                        } else {
                            NavigationLink(value: kind) {
                                BendKindRow(kind: kind, locked: false)
                            }
                        }
                    }
                }

                if !store.isPro {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Unlock BendCoach Pro", systemImage: "star.circle.fill")
                        }
                    } footer: {
                        Text("Saddles, back-to-backs, rolling offsets, unlimited benders and saved bends. One purchase, no subscription.")
                    }
                }
            }
            .navigationTitle("BendCoach")
            .navigationDestination(for: BendKind.self) { kind in
                calculator(for: kind)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    @ViewBuilder
    private func calculator(for kind: BendKind) -> some View {
        switch kind {
        case .stub90: StubUpView()
        case .offset: OffsetView()
        case .threePointSaddle: ThreePointSaddleView()
        case .fourPointSaddle: FourPointSaddleView()
        case .backToBack: BackToBackView()
        case .rollingOffset: RollingOffsetView()
        }
    }
}

struct BendKindRow: View {
    let kind: BendKind
    let locked: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbolName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(kind.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if locked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Pro")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
