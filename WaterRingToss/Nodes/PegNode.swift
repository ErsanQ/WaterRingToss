// Nodes/PegNode.swift
import SpriteKit

final class PegNode: SKNode {

    // Tip radius used for contact detection
    static let tipRadius: CGFloat = 5

    // رأس الإبرة (بالنسبة لمحتوى العقدة): y ≈ 26 من buildNeedle
    private let tipLocalY: CGFloat = 26
    // موضع قبعة العمود (نقطة الدخول من الأعلى) = رأس الإبرة
    var capPositionInParent: CGPoint {
        parent?.convert(CGPoint(x: position.x, y: position.y + tipLocalY), from: self) ?? CGPoint(x: position.x, y: position.y + tipLocalY)
    }

    init(at pos: CGPoint, sceneHeight: CGFloat) {
        super.init()
        position = pos
        buildPole(sceneHeight: sceneHeight)
        buildNeedle()
        setupPhysics()
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Pole ──────────────────────────────────────────────────────────────────
    private func buildPole(sceneHeight: CGFloat) {
        let poleH = position.y - 10
        // Main pole body – slightly tapered (wider at base)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -2.5, y: -poleH))
        path.addLine(to: CGPoint(x:  2.5, y: -poleH))
        path.addLine(to: CGPoint(x:  1.5, y: 0))
        path.addLine(to: CGPoint(x: -1.5, y: 0))
        path.closeSubpath()

        let pole = SKShapeNode(path: path)
        pole.fillColor   = UIColor.white.withAlphaComponent(0.32)
        pole.strokeColor = UIColor.white.withAlphaComponent(0.12)
        pole.lineWidth   = 0.5
        pole.zPosition   = 4
        addChild(pole)

        // Subtle inner shine on pole
        let shine = SKShapeNode(rectOf: CGSize(width: 1, height: poleH * 0.85))
        shine.fillColor   = UIColor.white.withAlphaComponent(0.18)
        shine.strokeColor = .clear
        shine.position    = CGPoint(x: -0.5, y: -poleH * 0.42)
        shine.zPosition   = 4.5
        addChild(shine)
    }

    // ── Needle / spike tip ────────────────────────────────────────────────────
    private func buildNeedle() {
        // Main spike: isoceles triangle, tip pointing up
        // Base width = 18 pt, height = 26 pt
        let tipH: CGFloat = 26
        let baseW: CGFloat = 18

        let spikePath = CGMutablePath()
        spikePath.move(to: CGPoint(x: 0,         y:  tipH))       // tip (top)
        spikePath.addLine(to: CGPoint(x:  baseW/2, y: -tipH * 0.15))
        // Concave shoulders for classic needle look
        spikePath.addQuadCurve(to: CGPoint(x: -baseW/2, y: -tipH * 0.15),
                                control: CGPoint(x: 0, y:  tipH * 0.10))
        spikePath.closeSubpath()

        // Drop shadow
        let shadowNode = SKShapeNode(path: spikePath)
        shadowNode.fillColor   = UIColor.black.withAlphaComponent(0.20)
        shadowNode.strokeColor = .clear
        shadowNode.position    = CGPoint(x: 2, y: -2)
        shadowNode.zPosition   = 5
        addChild(shadowNode)

        // Main spike body – metallic gradient look via two layers
        let spikeBase = SKShapeNode(path: spikePath)
        spikeBase.fillColor   = UIColor(red: 0.88, green: 0.95, blue: 1.0, alpha: 1)
        spikeBase.strokeColor = UIColor(red: 0.5, green: 0.85, blue: 1.0, alpha: 0.8)
        spikeBase.lineWidth   = 1.0
        spikeBase.zPosition   = 6
        addChild(spikeBase)

        // Left-face shading (darker)
        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: 0, y: tipH))
        leftPath.addLine(to: CGPoint(x: -baseW/2, y: -tipH * 0.15))
        leftPath.addQuadCurve(to: CGPoint(x: 0, y: 0),
                               control: CGPoint(x: -baseW * 0.1, y: tipH * 0.1))
        leftPath.closeSubpath()

        let leftFace = SKShapeNode(path: leftPath)
        leftFace.fillColor   = UIColor(red: 0.60, green: 0.80, blue: 0.95, alpha: 0.55)
        leftFace.strokeColor = .clear
        leftFace.zPosition   = 7
        addChild(leftFace)

        // Specular streak along right edge
        let specPath = CGMutablePath()
        specPath.move(to: CGPoint(x:  2, y: tipH * 0.88))
        specPath.addLine(to: CGPoint(x: baseW/2 * 0.55, y: -tipH * 0.05))
        let specNode = SKShapeNode(path: specPath)
        specNode.strokeColor = UIColor.white.withAlphaComponent(0.70)
        specNode.lineWidth   = 1.5
        specNode.lineCap     = .round
        specNode.zPosition   = 8
        addChild(specNode)

        // Tiny glow at tip
        let tipGlow = SKShapeNode(circleOfRadius: 3)
        tipGlow.fillColor   = UIColor.white.withAlphaComponent(0.85)
        tipGlow.strokeColor = .clear
        tipGlow.position    = CGPoint(x: 0, y: tipH)
        tipGlow.zPosition   = 9
        addChild(tipGlow)
    }

    // ── Physics – small circle at tip for ring contact ────────────────────────
    private func setupPhysics() {
        // Contact point = the needle tip
        let body = SKPhysicsBody(circleOfRadius: Self.tipRadius,
                                  center: CGPoint(x: 0, y: 22))
        body.isDynamic          = false
        body.categoryBitMask    = PhysicsCategories.peg
        body.collisionBitMask   = 0
        body.contactTestBitMask = PhysicsCategories.ring
        physicsBody = body
    }

    // ── Flash on ring scored ──────────────────────────────────────────────────
    func flash() {
        let glow = SKShapeNode(circleOfRadius: 24)
        glow.fillColor   = UIColor(red: 1, green: 0.84, blue: 0, alpha: 0.70)
        glow.strokeColor = .clear
        glow.position    = CGPoint(x: 0, y: 10)
        glow.zPosition   = 10
        addChild(glow)
        glow.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.38),
            SKAction.removeFromParent(),
        ]))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // موضع رأس الإبرة في إحداثيات المشهد (مفيد للأنيميشن/الاصطفاف)
    func tipWorldPosition() -> CGPoint {
        guard let scene = scene else { return convert(CGPoint(x: 0, y: tipLocalY), to: parent!) }
        return convert(CGPoint(x: 0, y: tipLocalY), to: scene)
    }
}

