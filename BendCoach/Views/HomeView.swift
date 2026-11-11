import SwiftUI
import BendKit

enum HomeRoute: Hashable {
    case benders
}

struct HomeView: View {
    @EnvironmentObject private var store: ProStore
    @Environment(\.currentBender) private var bender
    @State private var path = NavigationPath()
    @State private var showPaywall = Demo.screenName == "paywall"
    @State private var appliedDemo = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Your bender") {
                    NavigationLink(value: HomeRoute.benders) {
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
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .benders: BenderListView()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .onAppear(perform: applyDemo)
        }
    }

    private func applyDemo() {
        guard !appliedDemo else { return }
        appliedDemo = true
        if let kind = Demo.kind {
            path.append(kind)
        } else if Demo.screenName == "benders" {
            path.append(HomeRoute.benders)
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
