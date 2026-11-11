import SwiftUI
import BendKit

/// What the Bend tab shows next to its list: a calculator or the bender list.
enum HomeDestination: Hashable {
    case bend(BendKind)
    case benders
}

/// Screens pushed on top of a calculator.
enum HomeRoute: Hashable {
    case guided(BendPlan)
}

/// The Bend tab. A list and a detail column side by side on iPad; on iPhone the list pushes
/// the calculator as usual.
struct HomeView: View {
    @EnvironmentObject private var store: ProStore
    @Environment(\.currentBender) private var bender
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: HomeDestination?
    @State private var detailPath = NavigationPath()
    @State private var pendingRoute: HomeRoute?
    @State private var columns = NavigationSplitViewVisibility.all
    @State private var showPaywall = Demo.screenName == "paywall"
    @State private var showKeypadDemo = Demo.screenName == "keypad"
    @State private var appeared = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                Section("Your bender") {
                    NavigationLink(value: HomeDestination.benders) {
                        BenderSummaryLabel(bender: bender)
                    }
                }

                Section("Bends") {
                    ForEach(BendKind.allCases) { kind in
                        if isLocked(kind) {
                            Button {
                                showPaywall = true
                            } label: {
                                BendKindRow(kind: kind, locked: true)
                            }
                        } else {
                            NavigationLink(value: HomeDestination.bend(kind)) {
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
                                .foregroundStyle(Color.accentColor)
                        }
                    } footer: {
                        Text("Saddles, back-to-backs, rolling offsets, unlimited benders and saved bends. One purchase, no subscription.")
                    }
                }
            }
            .highVisSelection()
            .sheet(isPresented: $showKeypadDemo) {
                FractionKeypad(title: "Offset depth", initialValue: 6.5, denominator: 16) { _ in }
                    .presentationDetents([.large])
            }
            .navigationTitle("BendCoach")
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
        } detail: {
            NavigationStack(path: $detailPath) {
                detailRoot
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .guided(let plan): GuidedBendView(plan: plan)
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear(perform: firstAppear)
        .onChange(of: selection) {
            // A new pick starts a fresh stack in the detail column.
            detailPath = NavigationPath()
            if let pendingRoute {
                detailPath.append(pendingRoute)
                self.pendingRoute = nil
            }
        }
        .onChange(of: store.isPro) { _, isPro in
            if !isPro, case .bend(let kind) = selection, kind.requiresPro {
                selection = defaultSelection
            }
        }
    }

    @ViewBuilder
    private var detailRoot: some View {
        switch selection {
        case .bend(let kind):
            calculator(for: kind)
        case .benders:
            BenderListView()
        case nil:
            ContentUnavailableView("Pick a bend",
                                   systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                   description: Text("Choose a bend from the list to get your marks."))
        }
    }

    /// iPad opens on the offset calculator so the detail column is never blank.
    private var defaultSelection: HomeDestination? {
        horizontalSizeClass == .regular ? .bend(.offset) : nil
    }

    private func isLocked(_ kind: BendKind) -> Bool {
        kind.requiresPro && !store.isPro
    }

    private func firstAppear() {
        guard !appeared else { return }
        appeared = true
        if let kind = Demo.kind {
            selection = .bend(kind)
        } else if Demo.screenName == "benders" {
            selection = .benders
        } else if Demo.screenName == "guided", let plan = Demo.samplePlans().dropFirst().first {
            pendingRoute = .guided(plan)
            selection = .bend(plan.kind)
        } else if selection == nil {
            selection = defaultSelection
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
    @ScaledMetric(relativeTo: .title2) private var iconWidth: CGFloat = 36
    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let colors = RowColors(prominence: prominence)
        let stacked = typeSize.isAccessibilitySize
        let layout = AdaptiveRowLayout.layout(for: typeSize)
        layout {
            Image(systemName: kind.symbolName)
                .font(.title2)
                .foregroundStyle(colors.icon)
                .frame(width: stacked ? nil : iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.headline)
                    .foregroundStyle(colors.title)
                Text(kind.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(colors.detail)
                if locked && stacked {
                    Label("Pro", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(colors.detail)
                }
            }
            .frame(maxWidth: stacked ? .infinity : nil, alignment: .leading)
            if !stacked {
                Spacer(minLength: 8)
                if locked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(colors.detail)
                        .accessibilityLabel("Pro")
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(locked ? "Opens BendCoach Pro" : "")
    }
}
