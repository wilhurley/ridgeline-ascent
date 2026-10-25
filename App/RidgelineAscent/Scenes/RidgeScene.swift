import SpriteKit
import UIKit
import RidgelineCore

protocol GameDirecting: AnyObject {
    func sync(from simulation: RidgeSimulation)
    func announce(_ message: String)
}

final class RidgeScene: SKScene {
    let simulation: RidgeSimulation
    weak var director: GameDirecting?

    private let farRidge = SKShapeNode()
    private let nearRidge = SKShapeNode()
    private let avalanche = SKShapeNode()
    private let playfield = SKNode()
    private let climber = SKNode()
    private let flash = SKSpriteNode(color: .white, size: .zero)
    private var snow: SKEmitterNode?
    private var hazardNodes: [Int: SKShapeNode] = [:]
    private var dotTexture: SKTexture?
    private var lastTime: TimeInterval = 0
    private var trauma: CGFloat = 0
    private var laidOut = false
    private let haptics = HapticHook()

    init(simulation: RidgeSimulation) {
        self.simulation = simulation
        super.init(size: CGSize(width: 390, height: 844))
        backgroundColor = RidgeSK.color(0x10161E)
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    required init?(coder decoder: NSCoder) {
        fatalError("RidgeScene is built in code")
    }

    override func didMove(to view: SKView) {
        layoutIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutIfNeeded()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = frameDelta(currentTime)
        simulation.tick(dt: dt)
        let effects = simulation.drainEffects()
        if laidOut {
            present(effects, dt: dt)
            syncWorld()
        } else {
            note(effects)
        }
        director?.sync(from: simulation)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        steer(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        steer(touches)
    }

    private func steer(_ touches: Set<UITouch>) {
        guard let touch = touches.first, size.width > 1 else { return }
        let fraction = touch.location(in: self).x / size.width
        simulation.setSteer(normalizedX: Double(fraction))
    }

    private func frameDelta(_ currentTime: TimeInterval) -> Double {
        let dt: Double
        if lastTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = currentTime - lastTime
        }
        lastTime = currentTime
        if !dt.isFinite || dt <= 0 { return 1.0 / 60.0 }
        return min(dt, 0.05)
    }

    private func layoutIfNeeded() {
        guard size.width > 1, size.height > 1 else { return }
        if !laidOut {
            addChild(farRidge)
            addChild(nearRidge)
            avalanche.fillColor = RidgeSK.color(0xD5E4EF, 0.88)
            avalanche.strokeColor = RidgeSK.color(0xE7EEF4, 0.9)
            avalanche.lineWidth = 2
            avalanche.zPosition = 2
            addChild(avalanche)
            playfield.zPosition = 4
            addChild(playfield)
            buildClimber()
            playfield.addChild(climber)
            flash.color = .white
            flash.alpha = 0
            flash.zPosition = 20
            flash.anchorPoint = .zero
            addChild(flash)
            let texture = makeDotTexture()
            dotTexture = texture
            let emitter = SKEmitterNode()
            emitter.particleTexture = texture
            emitter.particleBirthRate = 26
            emitter.particleLifetime = 5.5
            emitter.particleLifetimeRange = 1.5
            emitter.particleSpeed = 36
            emitter.particleSpeedRange = 24
            emitter.emissionAngle = -.pi / 2
            emitter.emissionAngleRange = 0.35
            emitter.particleAlpha = 0.55
            emitter.particleAlphaRange = 0.2
            emitter.particleScale = 0.12
            emitter.particleScaleRange = 0.08
            emitter.particleColor = .white
            emitter.particleColorBlendFactor = 1
            emitter.zPosition = 8
            addChild(emitter)
            snow = emitter
            laidOut = true
        }
        farRidge.path = ridgePath(baseline: size.height * 0.42, peaks: [0.18, 0.42, 0.62, 0.84], heights: [0.16, 0.28, 0.2, 0.34])
        farRidge.fillColor = RidgeSK.color(0x243140)
        farRidge.strokeColor = .clear
        nearRidge.path = ridgePath(baseline: size.height * 0.22, peaks: [0.1, 0.36, 0.58, 0.78, 1.0], heights: [0.08, 0.14, 0.09, 0.18, 0.06])
        nearRidge.fillColor = RidgeSK.color(0x1A242E)
        nearRidge.strokeColor = .clear
        flash.size = size
        snow?.position = CGPoint(x: size.width / 2, y: size.height + 8)
        snow?.particlePositionRange = CGVector(dx: size.width, dy: 0)
    }

    private func ridgePath(baseline: CGFloat, peaks: [Double], heights: [Double]) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: baseline))
        for index in peaks.indices {
            let height = index < heights.count ? heights[index] : 0.1
            path.addLine(to: CGPoint(
                x: CGFloat(peaks[index]) * size.width,
                y: baseline + CGFloat(height) * size.height
            ))
        }
        path.addLine(to: CGPoint(x: size.width, y: baseline * 0.8))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.closeSubpath()
        return path
    }

    private func buildClimber() {
        let cloak = SKShapeNode(path: triangle(width: 22, height: 34))
        cloak.fillColor = RidgeSK.color(0xE7EEF4)
        cloak.strokeColor = RidgeSK.color(0x1A242E)
        cloak.lineWidth = 1.5
        cloak.position = CGPoint(x: 0, y: 6)
        climber.addChild(cloak)

        let hood = SKShapeNode(circleOfRadius: 6)
        hood.fillColor = RidgeSK.color(0x2A3848)
        hood.strokeColor = RidgeSK.color(0xE7EEF4)
        hood.lineWidth = 1
        hood.position = CGPoint(x: 0, y: 16)
        climber.addChild(hood)

        let scarf = SKShapeNode(rectOf: CGSize(width: 10, height: 4), cornerRadius: 1)
        scarf.fillColor = RidgeSK.color(0xE07A3D)
        scarf.strokeColor = .clear
        scarf.position = CGPoint(x: 2, y: 8)
        climber.addChild(scarf)

        let axe = SKShapeNode()
        let axePath = CGMutablePath()
        axePath.move(to: CGPoint(x: 8, y: 4))
        axePath.addLine(to: CGPoint(x: 20, y: 18))
        axe.path = axePath
        axe.strokeColor = RidgeSK.color(0x8FCBD6)
        axe.lineWidth = 2
        climber.addChild(axe)
        climber.zPosition = 6
    }

    private func present(_ effects: [SimEffect], dt: Double) {
        note(effects)
        for effect in effects {
            switch effect {
            case .screenShake(let amount):
                trauma = min(CGFloat(1), trauma + CGFloat(amount))
            case .attackFired(let style, let fromX, let fromY, let toX, let toY):
                drawStrike(style: style, from: CGPoint(x: screenX(fromX), y: screenY(fromY)), to: CGPoint(x: screenX(toX), y: screenY(toY)))
            case .hazardDamaged(let id):
                hazardNodes[id]?.run(.sequence([
                    .scale(to: 1.2, duration: 0.04),
                    .scale(to: 1, duration: 0.08)
                ]))
            case .hazardDefeated(_, let x, let y):
                burst(at: CGPoint(x: screenX(x), y: screenY(y)), color: RidgeSK.color(0xE7EEF4))
            case .climberDamaged(_):
                flash.alpha = 0.45
                flash.color = RidgeSK.color(0xD85A4A)
                flash.run(.fadeOut(withDuration: 0.18))
            case .summitReached:
                flash.alpha = 0.55
                flash.color = RidgeSK.color(0xD4A054)
                flash.run(.fadeOut(withDuration: 0.45))
                burst(at: climber.position, color: RidgeSK.color(0xE07A3D))
            case .revived:
                flash.alpha = 0.4
                flash.color = .white
                flash.run(.fadeOut(withDuration: 0.3))
            default:
                break
            }
        }
        trauma = max(CGFloat(0), trauma - CGFloat(dt) * 1.7)
        let magnitude = trauma * trauma * 16
        let jitter = CGPoint(
            x: CGFloat.random(in: -1...1) * magnitude,
            y: CGFloat.random(in: -1...1) * magnitude
        )
        playfield.position = jitter
        let drift = CGFloat(simulation.climber.y.truncatingRemainder(dividingBy: 280.0))
        farRidge.position = CGPoint(x: jitter.x * 0.25, y: -drift * 0.15)
        nearRidge.position = CGPoint(x: jitter.x * 0.4, y: -drift * 0.28)
    }

    private func note(_ effects: [SimEffect]) {
        for effect in effects {
            switch effect {
            case .attackFired(let style, _, _, _, _):
                switch style {
                case .iceAxe: SoundBoard.shared.play(.axe)
                case .flare: SoundBoard.shared.play(.flare)
                case .ropeHook: SoundBoard.shared.play(.hook)
                }
            case .hazardDefeated(_, _, _):
                SoundBoard.shared.play(.hit)
            case .climberDamaged(_):
                SoundBoard.shared.play(.hurt)
                haptics.play(.hurt)
            case .cairnReached:
                SoundBoard.shared.play(.cairn)
            case .fusionAwakened(let name):
                SoundBoard.shared.play(.summit)
                director?.announce("Fusion: \(name)")
            case .setBonusReached(let name):
                SoundBoard.shared.play(.ui)
                director?.announce(name)
            case .stageAdvanced(let stage):
                SoundBoard.shared.play(.ui)
                director?.announce(stage.displayName)
            case .bossAwakened:
                SoundBoard.shared.play(.hurt)
                director?.announce("The Cornice Tyrant")
            case .defeated(_):
                SoundBoard.shared.play(.death)
            case .summitReached:
                SoundBoard.shared.play(.summit)
                haptics.play(.summit)
            case .revived:
                SoundBoard.shared.play(.charm)
            case .hazardDamaged(_):
                break
            case .screenShake(_):
                break
            case .charmChosen(_):
                break
            }
        }
    }

    private func syncWorld() {
        climber.position = CGPoint(x: screenX(simulation.climber.x), y: screenY(simulation.climber.y))
        let top = max(CGFloat(0), screenY(simulation.avalancheY))
        let slab = CGMutablePath()
        slab.addRect(CGRect(x: 0, y: 0, width: size.width, height: top))
        avalanche.path = slab

        var seen = Set<Int>()
        for hazard in simulation.hazards {
            seen.insert(hazard.id)
            let node = hazardNodes[hazard.id] ?? makeHazardNode(hazard.kind)
            if node.parent == nil {
                playfield.addChild(node)
                hazardNodes[hazard.id] = node
            }
            node.position = CGPoint(x: screenX(hazard.x), y: screenY(hazard.y))
            if hazard.kind == .stormCrow {
                node.xScale = hazard.vx >= 0 ? 1 : -1
            }
        }
        let stale = hazardNodes.keys.filter { !seen.contains($0) }
        for id in stale {
            hazardNodes[id]?.removeFromParent()
            hazardNodes.removeValue(forKey: id)
        }
    }

    private func makeHazardNode(_ kind: HazardKind) -> SKShapeNode {
        let node: SKShapeNode
        switch kind {
        case .fallingRock:
            node = SKShapeNode(path: rockPath())
            node.fillColor = RidgeSK.color(0x8C8175)
            node.strokeColor = RidgeSK.color(0xE7EEF4, 0.35)
        case .iceWraith:
            node = SKShapeNode(path: diamond(radius: 16))
            node.fillColor = RidgeSK.color(0x8FCBD6, 0.85)
            node.strokeColor = .white
            node.glowWidth = 3
        case .stormCrow:
            node = SKShapeNode(path: chevron())
            node.fillColor = RidgeSK.color(0x1B2430)
            node.strokeColor = RidgeSK.color(0x7FB3C8)
            node.lineWidth = 1.5
        case .corniceTyrant:
            node = SKShapeNode(path: tyrantPath())
            node.fillColor = RidgeSK.color(0x243140, 0.95)
            node.strokeColor = RidgeSK.color(0xE7EEF4)
            node.lineWidth = 2
            node.glowWidth = 2
        }
        node.lineWidth = max(node.lineWidth, CGFloat(1))
        node.zPosition = kind == .corniceTyrant ? 5 : 3
        return node
    }

    private func drawStrike(style: GearStyle, from: CGPoint, to: CGPoint) {
        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        line.path = path
        switch style {
        case .iceAxe:
            line.strokeColor = RidgeSK.color(0xE7EEF4)
            line.lineWidth = 3
        case .flare:
            line.strokeColor = RidgeSK.color(0xE07A3D)
            line.lineWidth = 4
            line.glowWidth = 4
        case .ropeHook:
            line.strokeColor = RidgeSK.color(0xD4A054)
            line.lineWidth = 2
        }
        line.zPosition = 7
        playfield.addChild(line)
        line.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
    }

    private func burst(at point: CGPoint, color: UIColor) {
        guard let dotTexture else { return }
        let burst = SKEmitterNode()
        burst.particleTexture = dotTexture
        burst.particleBirthRate = 400
        burst.numParticlesToEmit = 16
        burst.particleLifetime = 0.35
        burst.particleSpeed = 140
        burst.particleSpeedRange = 60
        burst.emissionAngleRange = .pi * 2
        burst.particleScale = 0.18
        burst.particleScaleRange = 0.08
        burst.particleAlpha = 0.9
        burst.particleAlphaSpeed = -2
        burst.particleColor = color
        burst.particleColorBlendFactor = 1
        burst.position = point
        burst.zPosition = 9
        playfield.addChild(burst)
        burst.run(.sequence([.wait(forDuration: 0.45), .removeFromParent()]))
    }

    private func screenX(_ worldX: Double) -> CGFloat {
        CGFloat(worldX / simulation.config.ridgeWidth) * size.width
    }

    private func screenY(_ worldY: Double) -> CGFloat {
        let base = size.height * 0.34
        let scale = size.height / 560.0
        return base + CGFloat(worldY - simulation.climber.y) * scale
    }

    private func makeDotTexture() -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return SKTexture(image: image)
    }

    private func triangle(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: -height / 2))
        path.addLine(to: CGPoint(x: -width / 2, y: -height / 2))
        path.closeSubpath()
        return path
    }

    private func diamond(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: radius * 0.72, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -radius * 0.72, y: 0))
        path.closeSubpath()
        return path
    }

    private func rockPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -8, y: -6))
        path.addLine(to: CGPoint(x: -4, y: 8))
        path.addLine(to: CGPoint(x: 6, y: 7))
        path.addLine(to: CGPoint(x: 10, y: -2))
        path.addLine(to: CGPoint(x: 3, y: -9))
        path.closeSubpath()
        return path
    }

    private func chevron() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -12, y: 4))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -12, y: -4))
        path.addLine(to: CGPoint(x: -8, y: 0))
        path.closeSubpath()
        return path
    }

    private func tyrantPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -46, y: -10))
        path.addLine(to: CGPoint(x: -28, y: 18))
        path.addLine(to: CGPoint(x: -8, y: 6))
        path.addLine(to: CGPoint(x: 6, y: 26))
        path.addLine(to: CGPoint(x: 22, y: 4))
        path.addLine(to: CGPoint(x: 42, y: 16))
        path.addLine(to: CGPoint(x: 36, y: -14))
        path.closeSubpath()
        return path
    }
}
