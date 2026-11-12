import SwiftUI
import BendKit

/// The straight stick before bending, with every mark numbered where it goes.
struct StickLayoutView: View {
    let plan: BendPlan
    @Environment(\.lengthFormat) private var format
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 148

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
            let barY = size.height * 0.40
            let barHeight: CGFloat = 16
            let firstRowY = barY + barHeight / 2 + 16
            let rowStep: CGFloat = 24

            let bar = CGRect(x: inset, y: barY - barHeight / 2, width: usable, height: barHeight)
            context.fill(Path(roundedRect: bar, cornerRadius: 4), with: .color(Theme.conduit))
            context.stroke(Path(roundedRect: bar, cornerRadius: 4), with: .color(Theme.conduitEdge), lineWidth: 1)

            // Labels sit in rows under the bar. Each one takes the first row where it doesn't
            // touch a neighbour, so marks that sit close together stay readable.
            var rows: [[ClosedRange<CGFloat>]] = [[], [], []]
            let gap: CGFloat = 8
            func claim(_ span: ClosedRange<CGFloat>) -> Int {
                for row in rows.indices where !rows[row].contains(where: { $0.overlaps(span) }) {
                    rows[row].append(span)
                    return row
                }
                rows[rows.count - 1].append(span)
                return rows.count - 1
            }
            func rowY(_ row: Int) -> CGFloat { firstRowY + CGFloat(row) * rowStep }

            if fromEnd {
                let end = context.resolve(Text("End").font(.caption.weight(.semibold)).foregroundStyle(Color.secondary))
                let width = end.measure(in: size).width
                let row = claim((originX - gap)...(originX + width + gap))
                context.draw(end, at: CGPoint(x: originX, y: rowY(row)), anchor: .leading)
            }

            for mark in marks {
                let x = originX + CGFloat(mark.distance) * scale
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: barY - barHeight))
                tick.addLine(to: CGPoint(x: x, y: barY + barHeight))
                context.stroke(tick, with: .color(.accentColor), lineWidth: 3)

                let bubble = CGRect(x: x - 15, y: barY - barHeight - 32, width: 30, height: 30)
                context.fill(Path(ellipseIn: bubble), with: .color(Theme.highVis))
                context.stroke(Path(ellipseIn: bubble), with: .color(Theme.highVisEdge), lineWidth: 1)
                context.draw(Text(mark.label).font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.onHighVis),
                             at: CGPoint(x: bubble.midX, y: bubble.midY))

                let caption = context.resolve(
                    Text("\(Image(systemName: mark.benderMark.symbolName)) \(mark.distanceText(format))")
                        .font(.measurement(.footnote, weight: .semibold))
                        .foregroundStyle(Color.primary)
                )
                let half = caption.measure(in: size).width / 2
                let center = min(max(x, half + 2), size.width - half - 2)
                let row = claim((center - half - gap)...(center + half + gap))
                context.draw(caption, at: CGPoint(x: center, y: rowY(row)))
            }
        }
        .frame(height: height)
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
