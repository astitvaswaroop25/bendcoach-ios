import Foundation
import CoreMotion

/// Reads how steeply the phone's long edge is tilted, so the phone can sit on a
/// bent section of conduit and act as a digital level.
final class MotionLevel: ObservableObject {
    /// Tilt of the phone's long edge above (+) or below (−) horizontal, in degrees.
    @Published private(set) var rawAngle: Double = 0
    /// Reading taken on the straight part of the conduit before bending.
    @Published private(set) var zeroOffset: Double = 0
    @Published private(set) var isRunning = false

    let isAvailable: Bool
    private let manager = CMMotionManager()
    private var hasReading = false

    init() {
        isAvailable = manager.isDeviceMotionAvailable
    }

    /// Bend angle relative to the zero reading.
    var angle: Double { abs(rawAngle - zeroOffset) }

    func start() {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        hasReading = false
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            // The long (y) axis's elevation is the same whether the screen faces up or sideways.
            let clamped = max(-1.0, min(1.0, -gravity.y))
            let elevation = asin(clamped) * 180 / Double.pi
            // Light smoothing keeps the readout from flickering in a shaky hand.
            self.rawAngle = self.hasReading ? self.rawAngle * 0.7 + elevation * 0.3 : elevation
            self.hasReading = true
        }
        isRunning = true
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }

    func zero() {
        zeroOffset = rawAngle
    }

    func clearZero() {
        zeroOffset = 0
    }
}
