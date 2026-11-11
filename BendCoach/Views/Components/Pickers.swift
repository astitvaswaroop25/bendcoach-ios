import SwiftUI
import BendKit

/// Segmented picker for the angles cast on a hand bender.
struct AnglePicker: View {
    let title: String
    let angles: [Double]
    @Binding var selection: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            Picker(title, selection: $selection) {
                ForEach(angles, id: \.self) { angle in
                    Text(AngleFormat.string(angle)).tag(angle)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.adjustable")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(bender.name)
                    .foregroundStyle(Color.primary)
                Text("Take-up \(LengthFormat.standard.string(bender.takeUp)) · \(bender.conduitDescription)")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
