// Engine/PressureEngine.swift
import Foundation
import CoreGraphics
import Combine

/// Tracks how long a pump button is held and converts it to a physics impulse.
///
/// Real-world analogy: squeezing a rubber bulb.
///   - Short tap  → weak puff   → ring barely lifts, lots of lateral wobble
///   - Long hold  → strong jet  → ring shoots high, tight trajectory
///   - Over-press → inconsistent (human muscle tremor modelled as noise)
final class PressureEngine: ObservableObject {

    // ── Tuning ────────────────────────────────────────────────────────────────
    /// Seconds to reach maximum pressure
    private let maxBuildTime:  Double = 1.6
    /// Vertical force range (pts/s²) [weak … strong]
    private let minForce:      Double = 180
    private let maxForce:      Double = 560
    /// Lateral error at zero pressure (full wobble)
    private let maxHorizError: Double = 130
    /// Noise amplitude that mimics muscle tremor at >80% pressure
    private let tremorNoise:   Double = 0.12

    // ── Observable ───────────────────────────────────────────────────────────
    @Published private(set) var pressure: Double = 0   // 0..1

    // ── Private ───────────────────────────────────────────────────────────────
    private var buildTimer: Timer?
    private var pressStart: Date?

    // ── Public API ────────────────────────────────────────────────────────────

    /// Called when the button is first pressed (finger down).
    func beginPress() {
        pressStart = Date()
        buildTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self, let start = self.pressStart else { return }
            let elapsed = Date().timeIntervalSince(start)
            // Ease-in curve: slow build at first, faster near peak
            let raw = min(elapsed / self.maxBuildTime, 1.0)
            self.pressure = raw * raw           // quadratic ease-in
        }
    }

    /// Called when the button is released (finger up).
    /// Returns the impulse vector to apply to rings.
    func endPress(goLeft: Bool) -> CGVector {
        buildTimer?.invalidate()
        buildTimer  = nil
        let p       = pressure
        pressure    = 0
        pressStart  = nil
        return computeImpulse(pressure: p, goLeft: goLeft)
    }

    /// Live pressure value (0..1) — call from HUD gauge.
    var currentPressure: Double { pressure }

    // ── Private helpers ───────────────────────────────────────────────────────

    private func computeImpulse(pressure p: Double, goLeft: Bool) -> CGVector {
        // ① Vertical force — quadratic mapping gives satisfying feel
        let baseForce = minForce + (maxForce - minForce) * p

        // ② Realistic error model:
        //    • At low pressure: big random lateral drift (weak puff spreads)
        //    • At high pressure: small vertical noise (tremor)
        let lateralError  = (1.0 - p) * maxHorizError * Double.random(in: -1...1)
        let verticalNoise = p > 0.8 ? baseForce * tremorNoise * Double.random(in: -1...1) : 0
        let horizontalBias = goLeft
            ? -Double.random(in: 10...50) * p
            :  Double.random(in: 10...50) * p

        let dx = CGFloat(horizontalBias + lateralError)
        let dy = CGFloat(baseForce + verticalNoise)

        return CGVector(dx: dx, dy: dy)
    }
}
