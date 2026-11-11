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
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28
    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let colors = RowColors(prominence: prominence)
        let layout = AdaptiveRowLayout.layout(for: typeSize, spacing: 12)
        layout {
            Image(systemName: "wrench.adjustable")
                .foregroundStyle(colors.icon)
                .frame(width: typeSize.isAccessibilitySize ? nil : iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(bender.name)
                    .foregroundStyle(colors.title)
                Text(bender.summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(colors.detail)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
