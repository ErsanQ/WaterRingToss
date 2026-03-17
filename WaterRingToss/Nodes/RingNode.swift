// Nodes/RingNode.swift
import SpriteKit

/// A ring with:
///   • Dynamic physics from spawn (falls in at game start)
///   • Top-entry peg animation: glides above cap → squeezes through → slides down pole
///   • releaseFromPeg() uses isDynamic toggle (never destroys physicsBody)
///     so the impulse is applied instantly without frame-delay.
///   • Oil-fluid tuning: linearDamping 2.2, restitution 0.15
final class RingNode: SKNode {

    // ── Public ────────────────────────────────────────────────────────────────
    let ringColor: UIColor
    private(set) var isOnPeg  = false
    private(set) var pegIndex = -1

    // ── Geometry ──────────────────────────────────────────────────────────────
    let R:  CGFloat = 17
    private let ry: CGFloat = 9
    private let hR: CGFloat = 8

    // ── Init ──────────────────────────────────────────────────────────────────
    init(color: UIColor, at pos: CGPoint) {
        self.ringColor = color
        super.init()
        position = pos
        buildVisuals()
        setupPhysics()       // body created ONCE, never destroyed
        startIdleSpin()
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Visuals ───────────────────────────────────────────────────────────────
    private func buildVisuals() {
        let halo = ellipseShape(rx: R + 5, ry: ry + 3)
        halo.fillColor   = ringColor.withAlphaComponent(0.18)
        halo.strokeColor = .clear
        halo.zPosition   = -1
        addChild(halo)

        let outer = ellipseShape(rx: R, ry: ry)
        outer.fillColor   = ringColor
        outer.strokeColor = ringColor.darker(by: 0.25)
        outer.lineWidth   = 1.2
        outer.zPosition   = 1
        addChild(outer)

        let shadow = SKShapeNode(path: bottomHalfEllipse(rx: R-1, ry: ry-1))
        shadow.fillColor   = UIColor.black.withAlphaComponent(0.30)
        shadow.strokeColor = .clear
        shadow.zPosition   = 2
        addChild(shadow)

        let hole = ellipseShape(rx: hR, ry: hR * 0.55)
        hole.fillColor   = UIColor(red: 0, green: 0.50, blue: 0.70, alpha: 1)
        hole.strokeColor = UIColor.black.withAlphaComponent(0.15)
        hole.lineWidth   = 0.8
        hole.zPosition   = 3
        addChild(hole)

        let hl = SKShapeNode(path: topArc(rx: R-3, ry: ry-2))
        hl.strokeColor = UIColor.white.withAlphaComponent(0.55)
        hl.fillColor   = .clear
        hl.lineWidth   = 3
        hl.lineCap     = .round
        hl.zPosition   = 4
        addChild(hl)

        let spec = SKShapeNode(circleOfRadius: 2.5)
        spec.fillColor   = UIColor.white.withAlphaComponent(0.7)
        spec.strokeColor = .clear
        spec.position    = CGPoint(x: -R * 0.5, y: ry * 0.6)
        spec.zPosition   = 5
        addChild(spec)
    }

    // ── Physics – created ONCE, never destroyed ───────────────────────────────
    private func setupPhysics() {
        let body = SKPhysicsBody(circleOfRadius: R)
        body.isDynamic          = true
        body.categoryBitMask    = PhysicsCategories.ring
        body.collisionBitMask   = PhysicsCategories.wall | PhysicsCategories.ring
        body.contactTestBitMask = PhysicsCategories.peg
        body.restitution        = 0.15
        body.friction           = 0.60
        body.linearDamping      = 2.2
        body.angularDamping     = 2.0
        body.density            = 2.4
        physicsBody = body
    }

    // ── Idle Y-spin ───────────────────────────────────────────────────────────
    private func startIdleSpin() {
        let dur = Double.random(in: 2.2...4.0)
        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scaleX(to: -1, duration: dur),
            SKAction.scaleX(to:  1, duration: dur),
        ])), withKey: "idleSpin")
    }

    // ── Launch ────────────────────────────────────────────────────────────────
    func launch(impulse: CGVector) {
        guard !isOnPeg, let body = physicsBody else { return }
        body.isDynamic = true
        body.velocity  = .zero

        // Gradual oil-like push: 3 split impulses
        let step = CGVector(dx: impulse.dx / 3, dy: impulse.dy / 3)
        body.applyImpulse(step)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { body.applyImpulse(step) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { body.applyImpulse(step) }

        removeAction(forKey: "idleSpin")
        run(SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 2, duration: 1.4)
        ), withKey: "tumble")
        run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.09),
            SKAction.scale(to: 1.0, duration: 0.10),
        ]))
    }

    // ── Settle on peg ─────────────────────────────────────────────────────────
    // Uses isDynamic = false — body stays intact for instant release later.
    func settleOnPeg(pegCapPos: CGPoint, finalPos: CGPoint, idx: Int) {
        guard !isOnPeg else { return }
        isOnPeg  = true
        pegIndex = idx

        // ── Freeze physics (DO NOT nil the body) ──────────────────────────────
        physicsBody?.isDynamic          = false
        physicsBody?.velocity           = .zero
        physicsBody?.angularVelocity    = 0
        physicsBody?.contactTestBitMask = 0   // no contacts while settled

        removeAction(forKey: "tumble")
        removeAction(forKey: "idleSpin")
        removeAllActions()

        // Phase 1: glide above tip
        let aboveTip = CGPoint(x: pegCapPos.x, y: pegCapPos.y + R * 1.4)
        let ph1 = SKAction.group([
            SKAction.move(to: aboveTip,  duration: 0.16),
            SKAction.rotate(toAngle: 0,  duration: 0.16),
            SKAction.scale(to: 1.0,      duration: 0.16),
        ])
        // Phase 2: press over tip (squash)
        let ph2 = SKAction.group([
            SKAction.move(to: pegCapPos, duration: 0.12),
            SKAction.scaleX(to: 1.35,   duration: 0.07),
        ])
        // Phase 3: slide down to stack position
        let ph3 = SKAction.group([
            SKAction.move(to: finalPos,  duration: 0.20),
            SKAction.scaleX(to: 1.0,    duration: 0.10),
        ])
        // Phase 4: settle bounce
        let ph4 = SKAction.sequence([
            SKAction.scale(to: 1.18, duration: 0.07),
            SKAction.scale(to: 0.96, duration: 0.06),
            SKAction.scale(to: 1.0,  duration: 0.05),
        ])
        run(SKAction.sequence([ph1, ph2, ph3, ph4])) {
            self.startIdleSpin()
        }
    }

    // ── Release from peg (flip / strong pump) ────────────────────────────────
    // Toggles isDynamic = true instantly — no body recreation, no frame delay.
    func releaseFromPeg() {
        guard isOnPeg else { return }
        isOnPeg  = false
        pegIndex = -1

        removeAllActions()

        guard let body = physicsBody else { return }
        body.isDynamic          = true
        body.velocity           = .zero
        body.angularVelocity    = 0
        // Disable peg contact for 1.5 s (per AI_RAGS.md)
        body.contactTestBitMask = 0

        // Random scatter kick
        body.applyImpulse(CGVector(
            dx: CGFloat.random(in: -60...60),
            dy: CGFloat.random(in: 90...200)
        ))

        run(SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 2, duration: 1.1)
        ), withKey: "tumble")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.physicsBody?.contactTestBitMask = PhysicsCategories.peg
        }
    }

    // ── Shape helpers ─────────────────────────────────────────────────────────
    private func ellipseShape(rx: CGFloat, ry: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -rx, y: -ry, width: rx*2, height: ry*2))
        return SKShapeNode(path: path)
    }

    private func bottomHalfEllipse(rx: CGFloat, ry: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -rx, y: 0))
        path.addArc(center: .zero, radius: rx,
                    startAngle: .pi, endAngle: 2 * .pi, clockwise: false,
                    transform: CGAffineTransform(scaleX: 1, y: ry / rx))
        path.closeSubpath()
        return path
    }

    private func topArc(rx: CGFloat, ry: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: rx,
                    startAngle: -.pi * 0.85, endAngle: -.pi * 0.15, clockwise: false,
                    transform: CGAffineTransform(scaleX: 1, y: ry / rx))
        return path
    }
}

private extension UIColor {
    func darker(by fraction: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h,
                       saturation: min(s + fraction * 0.2, 1),
                       brightness: max(b - fraction, 0),
                       alpha: a)
    }
}
