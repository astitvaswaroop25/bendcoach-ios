import SwiftUI
import SwiftData
import BendKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedBend.createdAt, order: .reverse) private var saved: [SavedBend]

    var body: some View {
        NavigationStack {
            Group {
                if saved.isEmpty {
                    ContentUnavailableView("Nothing saved yet",
                                           systemImage: "tray",
                                           description: Text("Save a bend from any calculator to keep its marks for the next pull."))
                } else {
                    List {
                        ForEach(saved) { item in
                            NavigationLink {
                                SavedBendDetailView(item: item)
                            } label: {
                                SavedBendRow(item: item)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Saved")
            .toolbar {
                if !saved.isEmpty {
                    EditButton()
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(saved[index])
        }
    }
}

struct SavedBendRow: View {
    let item: SavedBend

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbolName)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text("\(item.kind.title) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
