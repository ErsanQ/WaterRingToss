// GameScene.swift
import SpriteKit
import CoreMotion

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // ── Dependencies ──────────────────────────────────────────────────────────
    private let model:    GameModel
    private let pressure: PressureEngine

    // ── State ─────────────────────────────────────────────────────────────────
    private var rings: [RingNode] = []
    private var pegs:  [PegNode]  = []
    private var pegStackCount: [Int: Int] = [:]
    // ترتيب الحلقات على كل وتد: index 0 = أعلى حلقة تحت الرأس
    private var pegStacks: [[RingNode]] = [[], []]

    // مستطيل الحجرة (للرسم والفيزياء)
    private var chamberRect: CGRect = .zero

    // تباعد الحلقات أسفل رأس الإبرة
    private let ringStackSpacing: CGFloat = 30

    // ── Nozzle placement (ratios) ────────────────────────────────────────────
    private let nozzleXLeftRatio:  CGFloat = 0.18
    private let nozzleXRightRatio: CGFloat = 0.82
    private let nozzleYRatio:      CGFloat = 0.08

    // ── Motion ────────────────────────────────────────────────────────────────
    private let motion        = CMMotionManager()
    private var deviceFlipped = false
    private var gravityFilter: CGVector = .zero
    private var lastAccel: CMAcceleration = .init(x: 0, y: 0, z: 0)

    // ── Ring colours ──────────────────────────────────────────────────────────
    private let ringColors: [UIColor] = [
        UIColor(red: 1.00, green: 0.30, blue: 0.43, alpha: 1),
        UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1),
        UIColor(red: 0.00, green: 0.76, blue: 0.66, alpha: 1),
        UIColor(red: 0.48, green: 0.36, blue: 0.94, alpha: 1),
        UIColor(red: 1.00, green: 0.55, blue: 0.26, alpha: 1),
        UIColor(red: 0.02, green: 0.84, blue: 0.63, alpha: 1),
    ]

    // ── Physics categories (match PhysicsCategories.swift) ────────────────────
    private enum PC {
        static let wall:          UInt32 = 0x1 << 0
        static let ring:          UInt32 = 0x1 << 1
        static let pegSolid:      UInt32 = 0x1 << 3
        static let pegHeadSensor: UInt32 = 0x1 << 4
    }

    // ── Aiming (per-nozzle adjustable angles) ─────────────────────────────────
    // Degrees from vertical (0 = عمودي للأعلى). موجّهة للداخل فقط.
    private var nozzleAngleLeftDeg:  CGFloat = 20
    private var nozzleAngleRightDeg: CGFloat = 20
    private let maxAimAngleDeg:      CGFloat = 90
    private let aimTouchRadius:      CGFloat = 36
    private var activeAimingSide:    AimingSide? = nil

    private enum AimingSide { case left, right }

    // Aim indicators
    private var leftAimIndicator:  SKNode?
    private var rightAimIndicator: SKNode?

    // ── Init ──────────────────────────────────────────────────────────────────
    init(model: GameModel, pressure: PressureEngine) {
        self.model    = model
        self.pressure = pressure
        super.init(size: .zero)
        isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsWorld.gravity         = CGVector(dx: 0, dy: -5.5)
        physicsWorld.contactDelegate = self
        physicsWorld.speed           = 0.70
        buildAll()
        startMotionUpdates()
    }

    override func willMove(from view: SKView) {
        motion.stopAccelerometerUpdates()
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    // ── Build ─────────────────────────────────────────────────────────────────
    private func buildAll() {
        removeAllChildren()
        buildWalls()
        buildOil()
        drawHoses()
        buildAimIndicators()
        buildPegs()
        buildRings()
        startBubbles()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Chamber & Oil
    // ─────────────────────────────────────────────────────────────────────────
    private func buildWalls() {
        let inset: CGFloat  = 10
        let corner: CGFloat = 22
        let rect = CGRect(x: inset, y: inset,
                          width:  size.width  - inset * 2,
                          height: size.height - inset * 2)
        chamberRect = rect.insetBy(dx: 2, dy: 2)

        let bezel = SKShapeNode(rect: rect, cornerRadius: corner)
        bezel.strokeColor = UIColor.black.withAlphaComponent(0.18)
        bezel.lineWidth   = 4
        bezel.fillColor   = .clear
        bezel.zPosition   = -20
        addChild(bezel)

        physicsBody = SKPhysicsBody(edgeLoopFrom: chamberRect)
        physicsBody?.friction           = 0.25
        physicsBody?.restitution        = 0.0
        physicsBody?.categoryBitMask    = PC.wall
        physicsBody?.collisionBitMask   = UInt32.max
        physicsBody?.contactTestBitMask = 0
    }

    private func buildOil() {
        let inner = chamberRect.insetBy(dx: 6, dy: 6)
        let oilColor = UIColor(red: 0.12, green: 0.58, blue: 0.52, alpha: 0.92)

        let oil = SKShapeNode(rect: inner, cornerRadius: 16)
        oil.fillColor   = oilColor
        oil.strokeColor = oilColor.withAlphaComponent(0.65)
        oil.lineWidth   = 2
        oil.zPosition   = -12
        addChild(oil)

        let glossHeight = max(14, inner.height * 0.2)
        let glossRect   = CGRect(x: inner.minX + 8,
                                  y: inner.maxY - glossHeight - 6,
                                  width: inner.width - 16,
                                  height: glossHeight)
        let gloss = SKShapeNode(path: UIBezierPath(roundedRect: glossRect, cornerRadius: 12).cgPath)
        gloss.fillColor   = UIColor.white.withAlphaComponent(0.14)
        gloss.strokeColor = .clear
        gloss.zPosition   = -11
        addChild(gloss)

        let wiggle = SKAction.customAction(withDuration: 3.8) { node, t in
            node.yScale = 1.0 + CGFloat(sin((t / 3.8) * .pi * 2)) * 0.012
        }
        oil.run(.repeatForever(wiggle))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Hoses
    // ─────────────────────────────────────────────────────────────────────────
    private func drawHoses() {
        func hosePath(from start: CGPoint, to nozzle: CGPoint, bulge: CGFloat) -> CGPath {
            let midX = (start.x + nozzle.x) / 2
            let cp1  = CGPoint(x: midX, y: start.y + (nozzle.y - start.y) * (0.25 + bulge))
            let cp2  = CGPoint(x: midX, y: start.y + (nozzle.y - start.y) * (0.75 - bulge))
            let path = UIBezierPath()
            path.move(to: start)
            path.addCurve(to: nozzle, controlPoint1: cp1, controlPoint2: cp2)
            return path.cgPath
        }

        let leftNozzle  = CGPoint(x: size.width * nozzleXLeftRatio,  y: chamberRect.minY + 6)
        let rightNozzle = CGPoint(x: size.width * nozzleXRightRatio, y: chamberRect.minY + 6)
        let buttonZoneY = chamberRect.minY - 56
        let leftStart   = CGPoint(x: max(0, chamberRect.minX - 64), y: buttonZoneY - 12)
        let rightStart  = CGPoint(x: min(size.width, chamberRect.maxX + 64), y: buttonZoneY - 12)

        func drawPort(at p: CGPoint) {
            let port = SKShapeNode(circleOfRadius: 7)
            port.fillColor   = UIColor.black.withAlphaComponent(0.22)
            port.strokeColor = UIColor.black.withAlphaComponent(0.28)
            port.lineWidth   = 1
            port.position    = CGPoint(x: p.x, y: chamberRect.minY + 4)
            port.zPosition   = -9
            addChild(port)
        }
        drawPort(at: leftNozzle)
        drawPort(at: rightNozzle)

        func addHose(path: CGPath, key: String) {
            let outer = SKShapeNode(path: path)
            outer.strokeColor = UIColor.darkGray
            outer.lineWidth   = 10
            outer.zPosition   = -30
            addChild(outer)

            let inner = SKShapeNode(path: path)
            inner.strokeColor = UIColor.black.withAlphaComponent(0.55)
            inner.lineWidth   = 6
            inner.zPosition   = -29
            addChild(inner)

            let hi = SKShapeNode(path: path)
            hi.strokeColor = UIColor.white.withAlphaComponent(0.25)
            hi.lineWidth   = 2
            hi.zPosition   = -28
            addChild(hi)

            let wobble = SKAction.repeatForever(.sequence([
                .customAction(withDuration: 0.6) { _, _ in outer.lineWidth = 10; inner.lineWidth = 6 },
                .customAction(withDuration: 0.6) { _, _ in outer.lineWidth = 11; inner.lineWidth = 7 },
            ]))
            outer.run(wobble, withKey: "\(key)-wobble-outer")
            inner.run(wobble, withKey: "\(key)-wobble-inner")
            hi.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.6),
                .fadeAlpha(to: 0.18, duration: 0.6),
            ])), withKey: "\(key)-wobble-hi")
        }

        addHose(path: hosePath(from: leftStart,  to: leftNozzle,  bulge: 0.08), key: "left")
        addHose(path: hosePath(from: rightStart, to: rightNozzle, bulge: 0.08), key: "right")
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Aim indicators (semi-circle + direction)
    // ─────────────────────────────────────────────────────────────────────────
    private func buildAimIndicators() {
        func makeIndicatorNode() -> SKNode {
            let container = SKNode()
            container.zPosition = -5

            let radius: CGFloat = 54
            let startAngle: CGFloat = 0
            let endAngle: CGFloat   = .pi / 2
            let arcPath = UIBezierPath(arcCenter: .zero,
                                       radius: radius,
                                       startAngle: startAngle,
                                       endAngle: endAngle,
                                       clockwise: true).cgPath
            let arc = SKShapeNode(path: arcPath)
            arc.strokeColor = UIColor.white.withAlphaComponent(0.25)
            arc.lineWidth = 2
            arc.fillColor = .clear
            arc.zPosition = -5
            container.addChild(arc)

            let dirPath = CGMutablePath()
            dirPath.move(to: .zero)
            dirPath.addLine(to: CGPoint(x: 0, y: radius))
            let dir = SKShapeNode(path: dirPath)
            dir.strokeColor = UIColor.white.withAlphaComponent(0.7)
            dir.lineWidth = 2
            dir.lineCap = .round
            dir.zPosition = -4
            container.addChild(dir)

            let arrow = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: radius + 0))
                p.addLine(to: CGPoint(x: -5, y: radius - 10))
                p.addLine(to: CGPoint(x: 5,  y: radius - 10))
                p.closeSubpath()
                return p
            }())
            arrow.fillColor = UIColor.white.withAlphaComponent(0.7)
            arrow.strokeColor = .clear
            arrow.zPosition = -4
            container.addChild(arrow)

            let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            label.fontSize = 12
            label.fontColor = UIColor.white.withAlphaComponent(0.85)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: radius + 16)
            label.name = "angleLabel"
            container.addChild(label)

            container.alpha = 0
            return container
        }

        leftAimIndicator?.removeFromParent()
        rightAimIndicator?.removeFromParent()

        let left = makeIndicatorNode()
        let right = makeIndicatorNode()

        left.position  = nozzlePoint(for: .left)
        right.position = nozzlePoint(for: .right)

        addChild(left)
        addChild(right)

        leftAimIndicator = left
        rightAimIndicator = right

        updateAimIndicator(side: .left, visible: false)
        updateAimIndicator(side: .right, visible: false)
    }

    private func updateAimIndicator(side: AimingSide, visible: Bool? = nil) {
        let node = (side == .left) ? leftAimIndicator : rightAimIndicator
        guard let node else { return }

        let deg = (side == .left) ? nozzleAngleLeftDeg : nozzleAngleRightDeg
        let rad = deg * .pi / 180

        node.zRotation = (side == .left) ? (-rad) : (rad)

        if let label = node.childNode(withName: "angleLabel") as? SKLabelNode {
            label.text = String(format: "%.0f°", deg)
        }

        if let visible = visible {
            let targetAlpha: CGFloat = visible ? 1.0 : 0.0
            node.removeAllActions()
            node.run(.fadeAlpha(to: targetAlpha, duration: 0.12))
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Pegs (longer + solid sides)
    // ─────────────────────────────────────────────────────────────────────────
    private func buildPegs() {
        let spacing: CGFloat = size.width * 0.28
        let centerX = size.width / 2
        let y       = chamberRect.midY

        pegs.removeAll()
        pegStacks = [[], []]
        for i in 0..<2 {
            let x   = centerX + (CGFloat(i) - 0.5) * spacing
            let peg = PegNode(at: CGPoint(x: x, y: y), sceneHeight: size.height)

            peg.removeAllChildren()

            // Longer, thicker shaft
            let shaftH: CGFloat = 120
            let shaftW: CGFloat = 6
            let shaft = SKShapeNode(rectOf: CGSize(width: shaftW, height: shaftH), cornerRadius: 3)
            shaft.fillColor   = UIColor.systemGray5
            shaft.strokeColor = UIColor.systemGray2
            shaft.lineWidth   = 1
            shaft.zPosition   = 1
            peg.addChild(shaft)

            // Needle tip
            let tipPath = CGMutablePath()
            tipPath.move(to:     CGPoint(x: -6, y:  shaftH/2 - 2))
            tipPath.addLine(to:  CGPoint(x:  0, y:  shaftH/2 + 18))
            tipPath.addLine(to:  CGPoint(x:  6, y:  shaftH/2 - 2))
            tipPath.closeSubpath()
            let tip = SKShapeNode(path: tipPath)
            tip.fillColor   = UIColor.systemGray3
            tip.strokeColor = UIColor.systemGray2
            tip.lineWidth   = 1
            tip.zPosition   = 2
            peg.addChild(tip)

            // Solid physics body (sides): thick and tall to block side/bottom
            let solidBody = SKPhysicsBody(rectangleOf: CGSize(width: shaftW + 10, height: shaftH))
            solidBody.isDynamic          = false
            solidBody.affectedByGravity  = false
            solidBody.friction           = 0.7
            solidBody.restitution        = 0.0
            solidBody.categoryBitMask    = PC.pegSolid
            solidBody.collisionBitMask   = UInt32.max
            solidBody.contactTestBitMask = UInt32.max
            peg.physicsBody = solidBody

            // Head sensor (contact only, no collision)
            let headSensor       = SKNode()
            headSensor.position  = CGPoint(x: 0, y: shaftH/2 + 10)
            headSensor.name      = "PegHeadSensor"
            let sensorBody       = SKPhysicsBody(circleOfRadius: 9)
            sensorBody.isDynamic          = false
            sensorBody.affectedByGravity  = false
            sensorBody.categoryBitMask    = PC.pegHeadSensor
            sensorBody.collisionBitMask   = 0
            sensorBody.contactTestBitMask = UInt32.max
            headSensor.physicsBody = sensorBody
            peg.addChild(headSensor)

            peg.zPosition = 5
            addChild(peg)
            pegs.append(peg)
            pegStackCount[i] = 0
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Rings
    // ─────────────────────────────────────────────────────────────────────────
    private func buildRings() {
        rings.removeAll()
        let bottomY = chamberRect.minY + 18
        let minX    = chamberRect.minX + 18
        let maxX    = chamberRect.maxX - 18

        for i in 0..<6 {
            let x    = CGFloat.random(in: minX...maxX)
            let y    = bottomY + CGFloat.random(in: -4...24)
            let ring = RingNode(color: ringColors[i % ringColors.count],
                                at: CGPoint(x: x, y: y))
            ring.zPosition = 6

            // Disable peg contact for 0.9 s while rings settle to floor
            ring.physicsBody?.contactTestBitMask = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                ring.physicsBody?.contactTestBitMask = PhysicsCategories.peg
            }

            addChild(ring)
            rings.append(ring)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Bubbles
    // ─────────────────────────────────────────────────────────────────────────
    private func startBubbles() {
        startBubbleEmitter(at: CGPoint(x: size.width * nozzleXLeftRatio,  y: chamberRect.minY + 6),
                           baseInterval: 0.28)
        startBubbleEmitter(at: CGPoint(x: size.width * nozzleXRightRatio, y: chamberRect.minY + 6),
                           baseInterval: 0.26)
    }

    private func startBubbleEmitter(at p: CGPoint, baseInterval: TimeInterval) {
        let key = "bubble-\(p.x.rounded())-\(p.y.rounded())"
        removeAction(forKey: key)
        let color = UIColor.white.withAlphaComponent(0.18)

        let spawn = SKAction.run { [weak self] in
            guard let self else { return }
            let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 3.0...5.0))
            bubble.fillColor   = color
            bubble.strokeColor = UIColor.white.withAlphaComponent(0.25)
            bubble.lineWidth   = 1
            bubble.position    = CGPoint(x: p.x + CGFloat.random(in: -7...7),
                                         y: p.y + CGFloat.random(in: -2...6))
            bubble.zPosition   = -1
            self.addChild(bubble)

            let dur  = TimeInterval.random(in: 1.0...1.4)
            let rise = SKAction.moveBy(x: CGFloat.random(in: -6...6),
                                       y: CGFloat.random(in: 80...130), duration: dur)
            let fade = SKAction.fadeOut(withDuration: dur)
            bubble.run(.sequence([.group([rise, fade]), .removeFromParent()]))
        }
        let wait = SKAction.wait(forDuration: baseInterval, withRange: baseInterval * 0.6)
        run(.repeatForever(.sequence([spawn, wait])), withKey: key)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Pump
    // Each button pumps from its OWN side at an angle toward the centre.
    func pump(goLeft: Bool) {
        guard !model.isGameOver else { return }

        let impulse       = pressure.endPress(goLeft: goLeft)
        let pressureLevel = min(Double(impulse.dy) / 560.0, 1.0)

        let leftNozzle  = CGPoint(x: size.width * nozzleXLeftRatio,  y: chamberRect.minY + 6)
        let rightNozzle = CGPoint(x: size.width * nozzleXRightRatio, y: chamberRect.minY + 6)

        let nozzleInside = goLeft ? leftNozzle : rightNozzle
        let hoseStart    = goLeft
            ? CGPoint(x: max(0, chamberRect.minX - 64),          y: chamberRect.minY - 68)
            : CGPoint(x: min(size.width, chamberRect.maxX + 64), y: chamberRect.minY - 68)

        // Angled direction from current aim
        let angleDeg: CGFloat = goLeft ? nozzleAngleLeftDeg : nozzleAngleRightDeg
        let angleRad: CGFloat = angleDeg * .pi / 180
        let dirX: CGFloat = goLeft ?  sin(angleRad) : -sin(angleRad)
        let dirY: CGFloat = cos(angleRad) // up component

        let reach: CGFloat = chamberRect.height * CGFloat(0.80 + pressureLevel * 0.15)
        let streamWidth: CGFloat = max(30, 70 * CGFloat(pressureLevel))

        // Check if a point falls within the angled stream cone
        func inAngledStream(_ p: CGPoint) -> Bool {
            let rel   = CGPoint(x: p.x - nozzleInside.x, y: p.y - nozzleInside.y)
            let along = rel.x * dirX + rel.y * dirY
            guard along > 0 && along <= reach else { return false }
            let perp  = abs(rel.x * dirY - rel.y * dirX)
            return perp <= streamWidth / 2
        }

        let freeInPath   = rings.filter { !$0.isOnPeg && inAngledStream($0.position) }
        let strongEject  = pressureLevel >= 0.80
        let peggedInPath = strongEject ? rings.filter { $0.isOnPeg && inAngledStream($0.position) } : []
        let hitsSomething = !freeInPath.isEmpty || !peggedInPath.isEmpty

        // Visual: stream along (dirX, dirY)
        showAirStreamUp(fromHose: hoseStart, intoPort: nozzleInside,
                        reach: reach, width: streamWidth,
                        pressure: pressureLevel, goLeft: goLeft,
                        hitsTarget: hitsSomething, dirX: dirX, dirY: dirY)

        if !hitsSomething {
            showMissPuffUp(from: nozzleInside, useRightNozzle: !goLeft)
            return
        }

        // Impulse: upward + angled inward matching stream direction
        let launchCount  = impulse.dy > 350 ? 2 : 1
        let inwardDx: CGFloat = dirX * 55 * CGFloat(pressureLevel)
        freeInPath.shuffled().prefix(launchCount).forEach {
            $0.launch(impulse: CGVector(dx: inwardDx, dy: impulse.dy))
        }

        if strongEject {
            peggedInPath.forEach { ring in
                let idx = ring.pegIndex
                ring.releaseFromPeg()
                model.ringRemoved()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    ring.launch(impulse: CGVector(dx: inwardDx * 0.6, dy: impulse.dy * 0.45))
                }
                if idx >= 0 { pegStackCount[idx] = max(0, (pegStackCount[idx] ?? 0) - 1) }
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        spawnRippleAt(nozzleInside)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Visual effects (stream follows angle)
    private func showAirStreamUp(fromHose hoseStart: CGPoint,
                                 intoPort nozzle: CGPoint,
                                 reach: CGFloat,
                                 width: CGFloat,
                                 pressure p: Double,
                                 goLeft: Bool,
                                 hitsTarget: Bool,
                                 dirX: CGFloat,
                                 dirY: CGFloat) {
        // Burst traveling from hose entry to port
        let burst = SKShapeNode(circleOfRadius: 6)
        burst.fillColor   = UIColor.white.withAlphaComponent(0.30)
        burst.strokeColor = UIColor.white.withAlphaComponent(0.40)
        burst.lineWidth   = 1
        burst.position    = hoseStart
        burst.zPosition   = -27
        addChild(burst)
        let hoseDur = 0.18 + 0.1 * (1 - p)
        burst.run(.sequence([
            .group([
                .move(to: CGPoint(x: nozzle.x + CGFloat.random(in: -2...2),
                                  y: nozzle.y), duration: hoseDur),
                .fadeOut(withDuration: hoseDur),
            ]),
            .removeFromParent(),
        ]))

        // Port spark
        let spark = SKShapeNode(circleOfRadius: 8)
        spark.fillColor   = UIColor.white.withAlphaComponent(0.22)
        spark.strokeColor = UIColor.white.withAlphaComponent(0.35)
        spark.lineWidth   = 1
        spark.position    = CGPoint(x: nozzle.x, y: nozzle.y)
        spark.zPosition   = -8
        addChild(spark)
        spark.run(.sequence([
            .group([.scale(to: 1.5, duration: 0.14), .fadeOut(withDuration: 0.14)]),
            .removeFromParent(),
        ]))

        // Stream dots along angled direction
        let dotCount = Int(max(10, min(26, p * 30)))
        let base: UIColor = hitsTarget
            ? UIColor.white.withAlphaComponent(0.60)
            : UIColor.white.withAlphaComponent(0.35)

        // perpendicular vector (normalized) to (dirX, dirY)
        let perpX = -dirY
        let perpY =  dirX

        for i in 0..<dotCount {
            let t = CGFloat(i) / CGFloat(max(1, dotCount - 1))
            let centerX = nozzle.x + dirX * reach * t
            let centerY = nozzle.y + dirY * reach * t

            // spread decreases with t
            let spread = width * (0.50 - 0.30 * t)
            let offset = CGFloat.random(in: -spread/2...spread/2)

            let x = centerX + perpX * offset
            let y = centerY + perpY * offset

            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2.0...4.0))
            dot.fillColor   = base
            dot.strokeColor = UIColor.white.withAlphaComponent(0.35)
            dot.lineWidth   = 1
            dot.position    = CGPoint(x: x, y: y)
            dot.zPosition   = -2
            addChild(dot)

            let drift = CGFloat.random(in: 6...12) * (1 - t)
            let driftX = perpX * drift * (goLeft ? -1 : 1)
            let driftY = perpY * drift * (goLeft ? -1 : 1)

            dot.run(.sequence([
                .group([
                    .moveBy(x: driftX, y: driftY, duration: 0.30),
                    .fadeOut(withDuration: 0.30),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    private func showMissPuffUp(from nozzle: CGPoint, useRightNozzle: Bool) {
        let puff = SKShapeNode(circleOfRadius: 10)
        puff.fillColor   = UIColor.white.withAlphaComponent(0.22)
        puff.strokeColor = UIColor.white.withAlphaComponent(0.35)
        puff.lineWidth   = 1
        puff.position    = nozzle
        puff.zPosition   = -1
        addChild(puff)
        let dx: CGFloat = (useRightNozzle ? -1 : 1) * CGFloat.random(in: 8...16)
        puff.run(.sequence([
            .group([.scale(to: 1.7, duration: 0.20), .moveBy(x: dx, y: 22, duration: 0.20), .fadeOut(withDuration: 0.20)]),
            .removeFromParent(),
        ]))
    }

    private func spawnRippleAt(_ p: CGPoint) {
        let ripple = SKShapeNode(circleOfRadius: 6)
        ripple.fillColor   = .clear
        ripple.strokeColor = UIColor.white.withAlphaComponent(0.45)
        ripple.lineWidth   = 2
        ripple.position    = p
        ripple.zPosition   = -1
        addChild(ripple)
        ripple.run(.sequence([
            .group([.scale(to: 3.0, duration: 0.30), .fadeOut(withDuration: 0.30)]),
            .removeFromParent(),
        ]))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Contact / Stacking
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node,
              let nodeB = contact.bodyB.node else { return }

        guard let (sensor, ring) = matchSensorAndRing(nodeA: nodeA, nodeB: nodeB) else { return }
        guard !ring.isOnPeg else { return }

        let sensorWorldPos = sensor.convert(CGPoint.zero, to: self)
        guard isComingFromAbove(ring: ring, relativeTo: sensorWorldPos) else { return }
        guard let pegIdx = pegIndex(for: sensor) else { return }

        trySettle(ring: ring, atPegIndex: pegIdx, pegHead: sensorWorldPos)
    }

    private func matchSensorAndRing(nodeA: SKNode, nodeB: SKNode) -> (sensor: SKNode, ring: RingNode)? {
        if nodeA.name == "PegHeadSensor", let r = nodeB as? RingNode { return (nodeA, r) }
        if nodeB.name == "PegHeadSensor", let r = nodeA as? RingNode { return (nodeB, r) }
        return nil
    }

    private func pegIndex(for sensor: SKNode) -> Int? {
        guard let peg = sensor.parent as? PegNode else { return nil }
        return pegs.firstIndex { $0 === peg }
    }

    private func isComingFromAbove(ring: RingNode, relativeTo pegHead: CGPoint) -> Bool {
        guard let body = ring.physicsBody else { return false }
        // يسمح بالدخول عندما تكون فوق الرأس وبسرعة هابطة منخفضة
        return ring.position.y > pegHead.y + 4 && body.velocity.dy < 80
    }

    private func trySettle(ring: RingNode, atPegIndex idx: Int, pegHead: CGPoint) {
        // 1) حرك الحلقات الموجودة للأسفل درجة واحدة إضافية لتفريغ خانة أعلى الوتد
        let existing = pegStacks[idx]
        for (order, r) in existing.enumerated() {
            // كان سابقاً (order + 1)، الآن نترك خانة 1 للجديدة، فتصير (order + 2)
            let targetY = pegHead.y - ringStackSpacing * CGFloat(order + 2)
            let target  = CGPoint(x: pegs[idx].position.x, y: targetY)
            r.removeAllActions()
            r.run(SKAction.move(to: target, duration: 0.18))
        }

        // 2) الحلقة الجديدة تذهب إلى الخانة 1 تحت الرأس مباشرة
        let topSlotPos = CGPoint(x: pegs[idx].position.x, y: pegHead.y - ringStackSpacing * 1)
        ring.settleOnPeg(pegCapPos: pegHead, finalPos: topSlotPos, idx: idx)

        // 3) حدّث المكدس: الجديدة في الأعلى (index 0)
        pegStacks[idx].insert(ring, at: 0)
        pegStackCount[idx] = pegStacks[idx].count

        pegs[idx].flash()
        model.ringScored()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Release All (device flip)
    private func releaseAllFromPegs() {
        let pegged = rings.filter { $0.isOnPeg }
        guard !pegged.isEmpty else { return }

        pegged.forEach { ring in
            let idx = ring.pegIndex
            ring.releaseFromPeg()
            model.ringRemoved()
            if idx >= 0 {
                // حدث المكدس أيضاً
                if let pos = pegStacks[idx].firstIndex(where: { $0 === ring }) {
                    pegStacks[idx].remove(at: pos)
                }
                pegStackCount[idx] = pegStacks[idx].count
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Motion (tilt gravity + flip detection)
    private func startMotionUpdates() {
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 60.0
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let a = data?.acceleration else { return }
                self.lastAccel = a

                // Smooth gravity with low-pass filter
                let gx  = CGFloat(a.x) * 9.8
                let gy  = CGFloat(a.y) * 9.8
                let raw = CGVector(dx: gx, dy: gy)
                let alpha: CGFloat = 0.12
                self.gravityFilter = CGVector(
                    dx: self.gravityFilter.dx * (1 - alpha) + raw.dx * alpha,
                    dy: self.gravityFilter.dy * (1 - alpha) + raw.dy * alpha
                )
                self.physicsWorld.gravity = self.gravityFilter

                // Flip detection
                let flipped = a.y > 0.65
                if flipped && !self.deviceFlipped {
                    DispatchQueue.main.async { self.releaseAllFromPegs() }
                }
                self.deviceFlipped = flipped
            }
        } else {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(orientationChanged),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )
            applyGravityForCurrentOrientation()
        }
    }

    @objc private func orientationChanged() {
        applyGravityForCurrentOrientation()
        let flipped = UIDevice.current.orientation == .portraitUpsideDown
        if flipped && !deviceFlipped {
            releaseAllFromPegs()
        }
        deviceFlipped = flipped
    }

    private func applyGravityForCurrentOrientation() {
        switch UIDevice.current.orientation {
        case .landscapeLeft:       physicsWorld.gravity = CGVector(dx:  5.5, dy: -2.0)
        case .landscapeRight:      physicsWorld.gravity = CGVector(dx: -5.5, dy: -2.0)
        case .portraitUpsideDown:  physicsWorld.gravity = CGVector(dx:  0.0, dy:  5.5)
        default:                   physicsWorld.gravity = CGVector(dx:  0.0, dy: -5.5)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Touch aiming (pan near each nozzle)
    private func nozzlePoint(for side: AimingSide) -> CGPoint {
        let xRatio = (side == .left) ? nozzleXLeftRatio : nozzleXRightRatio
        return CGPoint(x: size.width * xRatio, y: chamberRect.minY + 6)
    }

    private func sideForTouch(_ p: CGPoint) -> AimingSide? {
        let left = nozzlePoint(for: .left)
        if hypot(p.x - left.x, p.y - left.y) <= aimTouchRadius { return .left }
        let right = nozzlePoint(for: .right)
        if hypot(p.x - right.x, p.y - right.y) <= aimTouchRadius { return .right }
        return nil
    }

    private func updateAim(for side: AimingSide, with touchPoint: CGPoint) {
        let nozzle = nozzlePoint(for: side)
        let dx = touchPoint.x - nozzle.x
        let dy = touchPoint.y - nozzle.y
        guard dy > 0 else { return }

        let angleFromVertical = atan(abs(dx) / dy) * 180 / .pi

        switch side {
        case .left:
            guard dx >= 0 else { return }
            nozzleAngleLeftDeg = max(0, min(maxAimAngleDeg, angleFromVertical))
            updateAimIndicator(side: .left, visible: true)
        case .right:
            guard dx <= 0 else { return }
            nozzleAngleRightDeg = max(0, min(maxAimAngleDeg, angleFromVertical))
            updateAimIndicator(side: .right, visible: true)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        if let side = sideForTouch(p) {
            activeAimingSide = side
            updateAim(for: side, with: p)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            activeAimingSide = nil
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let side = activeAimingSide, let t = touches.first else { return }
        let p = t.location(in: self)
        updateAim(for: side, with: p)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let side = activeAimingSide {
            updateAimIndicator(side: side, visible: false)
        }
        activeAimingSide = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let side = activeAimingSide {
            updateAimIndicator(side: side, visible: false)
        }
        activeAimingSide = nil
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Reset
    func resetScene() {
        motion.stopAccelerometerUpdates()
        NotificationCenter.default.removeObserver(self)

        removeAllActions()
        removeAllChildren()
        rings.removeAll()
        pegs.removeAll()
        pegStackCount.removeAll()
        pegStacks = [[], []]
        deviceFlipped = false
        gravityFilter = .zero

        physicsWorld.gravity         = CGVector(dx: 0, dy: -5.5)
        physicsWorld.contactDelegate = self
        physicsWorld.speed           = 0.70

        buildAll()
        startMotionUpdates()
    }
}
