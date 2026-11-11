import SwiftUI
import SwiftData
import BendKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \SavedBend.createdAt, order: .reverse) private var saved: [SavedBend]
    @State private var selection: SavedBend?
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Group {
                if saved.isEmpty {
                    ContentUnavailableView("Nothing saved yet",
                                           systemImage: "tray",
                                           description: Text("Save a bend from any calculator to keep its marks for the next pull."))
                } else {
                    List(selection: $selection) {
                        ForEach(saved) { item in
                            NavigationLink(value: item) {
                                SavedBendRow(item: item)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .highVisSelection()
                }
            }
            .navigationTitle("Saved")
            .toolbar {
                if !saved.isEmpty {
                    EditButton()
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
        } detail: {
            NavigationStack {
                if let selection {
                    SavedBendDetailView(item: selection)
                        .id(selection)
                } else {
                    ContentUnavailableView("No bend selected", systemImage: "tray")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            insertDemoBends()
            selectFirstIfRoomy()
        }
        .onChange(of: saved) {
            selectFirstIfRoomy()
        }
    }

    /// On iPad the newest bend opens in the detail column, so it is never blank.
    private func selectFirstIfRoomy() {
        guard horizontalSizeClass == .regular else { return }
        if let selection, saved.contains(selection) { return }
        selection = saved.first
    }

    private func insertDemoBends() {
        guard Demo.screenName == "saved", saved.isEmpty else { return }
        for plan in Demo.samplePlans() {
            modelContext.insert(SavedBend(plan: plan, title: plan.title(format: .standard)))
        }
    }

    private func delete(_ offsets: IndexSet) {
        let doomed = offsets.map { saved[$0] }
        if let selection, doomed.contains(selection) {
            self.selection = nil
        }
        for item in doomed {
            modelContext.delete(item)
        }
    }
}

struct SavedBendRow: View {
    let item: SavedBend
    @ScaledMetric(relativeTo: .headline) private var iconWidth: CGFloat = 28
    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let colors = RowColors(prominence: prominence)
        let layout = AdaptiveRowLayout.layout(for: typeSize, spacing: 12)
        layout {
            Image(systemName: item.kind.symbolName)
                .foregroundStyle(colors.icon)
                .frame(width: typeSize.isAccessibilitySize ? nil : iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(colors.title)
                Text("\(item.kind.title) · \(item.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                    .font(.subheadline)
                    .foregroundStyle(colors.detail)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct SavedBendDetailView: View {
    let item: SavedBend

    var body: some View {
        Group {
            if let plan = item.plan {
                Form {
                    PlanSections(plan: plan, allowsSaving: false)
                }
            } else {
                ContentUnavailableView("Couldn't open this bend", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
