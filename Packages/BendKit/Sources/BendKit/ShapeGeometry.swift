import Foundation

public struct Bounds2D: Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
}

public enum ShapeGeometry {
    /// Rounds each interior corner of a polyline with an arc of `radius`, the way a bender
    /// shoe would. Arcs shrink when corners are too close together so they never overlap.
    public static func filleted(_ points: [Point2D], radius: Double, segmentsPerArc: Int = 12) -> [Point2D] {
        guard points.count >= 3, radius > 0, segmentsPerArc > 0 else { return points }
        var result: [Point2D] = [points[0]]
        let lastIndex = points.count - 1

        for index in 1..<lastIndex {
            let previous = points[index - 1]
            let corner = points[index]
            let next = points[index + 1]
            let lengthIn = distance(previous, corner)
            let lengthOut = distance(corner, next)
            guard lengthIn > 1e-9, lengthOut > 1e-9 else {
                result.append(corner)
                continue
            }

            let toPrevious = Point2D((previous.x - corner.x) / lengthIn, (previous.y - corner.y) / lengthIn)
            let toNext = Point2D((next.x - corner.x) / lengthOut, (next.y - corner.y) / lengthOut)
            let cosine = max(-1, min(1, toPrevious.x * toNext.x + toPrevious.y * toNext.y))
            let interior = acos(cosine)
            let deflection = Double.pi - interior
            guard deflection > 1e-6, interior > 1e-6 else {
                result.append(corner)
                continue
            }

            // End segments can give their whole length to the arc; shared segments only half.
            let maxIn = (index - 1 == 0) ? lengthIn : lengthIn / 2
            let maxOut = (index + 1 == lastIndex) ? lengthOut : lengthOut / 2
            let halfTurn = tan(deflection / 2)
            let tangentLength = min(radius * halfTurn, maxIn, maxOut)
            let arcRadius = tangentLength / halfTurn

            let start = Point2D(corner.x + toPrevious.x * tangentLength, corner.y + toPrevious.y * tangentLength)
            let end = Point2D(corner.x + toNext.x * tangentLength, corner.y + toNext.y * tangentLength)
            let bisectorX = toPrevious.x + toNext.x
            let bisectorY = toPrevious.y + toNext.y
            let bisectorLength = (bisectorX * bisectorX + bisectorY * bisectorY).squareRoot()
            guard bisectorLength > 1e-9 else {
                result.append(corner)
                continue
            }
            let centerDistance = (arcRadius * arcRadius + tangentLength * tangentLength).squareRoot()
            let center = Point2D(corner.x + bisectorX / bisectorLength * centerDistance,
                                 corner.y + bisectorY / bisectorLength * centerDistance)

            let startAngle = atan2(start.y - center.y, start.x - center.x)
            var sweep = atan2(end.y - center.y, end.x - center.x) - startAngle
            while sweep > Double.pi { sweep -= 2 * Double.pi }
            while sweep <= -Double.pi { sweep += 2 * Double.pi }

            for step in 0...segmentsPerArc {
                let angle = startAngle + sweep * Double(step) / Double(segmentsPerArc)
                result.append(Point2D(center.x + cos(angle) * arcRadius, center.y + sin(angle) * arcRadius))
            }
        }
        result.append(points[lastIndex])
        return result
    }

    public static func distance(_ a: Point2D, _ b: Point2D) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }

    public static func bounds(_ points: [Point2D]) -> Bounds2D? {
        guard let first = points.first else { return nil }
        var box = Bounds2D(minX: first.x, minY: first.y, maxX: first.x, maxY: first.y)
        for point in points.dropFirst() {
            box.minX = min(box.minX, point.x)
            box.minY = min(box.minY, point.y)
            box.maxX = max(box.maxX, point.x)
            box.maxY = max(box.maxY, point.y)
        }
        return box
    }
}
