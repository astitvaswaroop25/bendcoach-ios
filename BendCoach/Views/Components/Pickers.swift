import SwiftUI
import BendKit

/// Picker for the angles cast on a hand bender.
struct AnglePicker: View {
    let title: String
    let angles: [Double]
    @Binding var selection: Double

    var body: some View {
        ChoicePicker(title: title, options: angles, label: { AngleFormat.string($0) }, selection: $selection)
    }
}

/// Shows which bender the numbers use, with a link to change it.
struct BenderSummaryRow: View {
    @Environment(\.currentBender) private var bender

    var body: some View {
        NavigationLink {
            BenderListView()
        } label: {
            BenderSummaryLabel(bender: bender)
        }
    }
}

struct BenderSummaryLabel: View {
    let bender: BenderProfile
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let colors = RowColors(prominence: prominence)
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(bender.name)
                    .foregroundStyle(colors.title)
                Text(bender.summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(colors.detail)
            }
        } icon: {
            Image(systemName: "wrench.adjustable")
                .foregroundStyle(colors.icon)
        }
        .padding(.vertical, 2)
    }
}
