import SwiftUI
import BendKit

/// The straight stick before bending, with every mark numbered where it goes.
struct StickLayoutView: View {
    let plan: BendPlan
    @Environment(\.lengthFormat) private var format

    /// Marks that can be laid out on the straight stick before any bending.
    private var stickMarks: [BendMark] {
        plan.marks.filter { $0.reference != .backOfFirstBend }
    }

    var body: some View {
        Canvas { context, size in
            let marks = stickMarks
            guard !marks.isEmpty else { return }

            let fromEnd = marks[0].reference == .conduitEnd
            let distances = marks.map { $0.distance }
            let low = min(0, distances.min() ?? 0)
            let high = max(distances.max() ?? 0, 12)
            let span = high - low
            let inset: CGFloat = 18
            let usable = size.width - inset * 2
            let lead = fromEnd ? 0 : span * 0.12
            let shown = span * 1.14 + lead
            let scale = usable / CGFloat(shown)
            let originX = inset + CGFloat(lead - low) * scale
            let barY = size.height * 0.42
            let barHeight: CGFloat = 14

            let bar = CGRect(x: inset, y: barY - barHeight / 2, width: usable, height: barHeight)
            context.fill(Path(roundedRect: bar, cornerRadius: 4), with: .color(Theme.conduit))
            context.stroke(Path(roundedRect: bar, cornerRadius: 4), with: .color(Theme.conduitEdge), lineWidth: 1)

            if fromEnd {
                context.draw(Text("END").font(.caption2.bold()).foregroundStyle(Color.secondary),
                             at: CGPoint(x: originX, y: barY + barHeight + 30), anchor: .leading)
            }

            for (index, mark) in marks.enumerated() {
                let x = originX + CGFloat(mark.distance) * scale
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: barY - barHeight))
                tick.addLine(to: CGPoint(x: x, y: barY + barHeight))
                context.stroke(tick, with: .color(.accentColor), lineWidth: 3)

                let bubble = CGRect(x: x - 13, y: barY - barHeight - 30, width: 26, height: 26)
                context.fill(Path(ellipseIn: bubble), with: .color(.accentColor))
                context.draw(Text(mark.label).font(.headline).foregroundStyle(Color.white),
                             at: CGPoint(x: bubble.midX, y: bubble.midY))

                // Stagger labels so marks that sit close together stay readable.
                let rowOffset: CGFloat = index.isMultiple(of: 2) ? 0 : 28
                let caption = "\(mark.benderMark.glyph) \(mark.distanceText(format))"
                context.draw(Text(caption).font(.caption.monospacedDigit()).foregroundStyle(Color.primary),
                             at: CGPoint(x: x, y: barY + barHeight + 14 + rowOffset))
            }
        }
        .frame(height: 132)
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        stickMarks
            .map { "Mark \($0.label) at \($0.distanceText(format)) \($0.referenceText)" }
            .joined(separator: ", ")
    }
}

/// The finished conduit, drawn with the bender's radius at each bend.
struct ShapePreviewView: View {
    let plan: BendPlan
    let radius: Double

    var body: some View {
        Canvas { context, size in
            let points = ShapeGeometry.filleted(plan.shape, radius: radius)
            guard points.count > 1, let box = ShapeGeometry.bounds(points) else { return }
            let inset: CGFloat = 20
            let width = max(box.width, 1)
            let height = max(box.height, 1)
            let scale = min((size.width - inset * 2) / CGFloat(width), (size.height - inset * 2) / CGFloat(height))
            let offsetX = (size.width - CGFloat(width) * scale) / 2
            let offsetY = (size.height - CGFloat(height) * scale) / 2

            var path = Path()
            for (index, point) in points.enumerated() {
                let mapped = CGPoint(x: offsetX + CGFloat(point.x - box.minX) * scale,
                                     y: size.height - offsetY - CGFloat(point.y - box.minY) * scale)
                if index == 0 {
                    path.move(to: mapped)
                } else {
                    path.addLine(to: mapped)
                }
            }
            context.stroke(path, with: .color(Theme.conduitEdge),
                           style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Theme.conduit),
                           style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 150)
        .accessibilityHidden(true)
    }
}
