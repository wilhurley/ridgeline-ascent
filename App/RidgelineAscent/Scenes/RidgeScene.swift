import SpriteKit
import UIKit
import RidgelineCore

protocol GameDirecting: AnyObject {
    func sync(from simulation: RidgeSimulation)
    func announce(_ message: String)
    func noteWeather(_ kind: WeatherKind)
    var ticksSimulation: Bool { get }
}

final class RidgeScene: SKScene {
    let simulation: RidgeSimulation
    weak var director: GameDirecting?

    private let backdrop = ParallaxRidge()
    private let veil = WeatherVeil()
    private let avalanche = SKShapeNode()
    private let playfield = SKNode()
    private let climber = SKNode()
    private let flash = SKSpriteNode(color: .white, size: .zero)
    private var avalancheDrift: SKEmitterNode?
    private var figure: ClimberRendering?
    private var hazardNodes: [Int: HazardVisual] = [:]
    private var previousClimberX = -1.0
    private var omenNodes: [Int: SKShapeNode] = [:]
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
        let moving = director?.ticksSimulation != false
        let pointsPerUnit = size.height / 560
        let visualRadius = CGFloat(SimConfig.presentedClimberRadius)
        if !moving {
            lastTime = currentTime
            _ = climberHorizontalSpeed(dt: 0)
            figure?.layout(pointsPerUnit: pointsPerUnit, hitRadius: visualRadius)
            figure?.update(time: currentTime, gear: simulation.loadout.gearStyle, horizontalSpeed: 0, moving: false)
            return
        }
        let dt = frameDelta(currentTime)
        let speed = climberHorizontalSpeed(dt: dt)
        simulation.tick(dt: dt)
        let effects = simulation.drainEffects()
        if laidOut {
            present(effects, dt: dt)
            syncWorld(time: currentTime)
        } else {
            note(effects)
        }
        figure?.layout(pointsPerUnit: pointsPerUnit, hitRadius: visualRadius)
        figure?.update(time: currentTime, gear: simulation.loadout.gearStyle, horizontalSpeed: speed, moving: true)
        director?.sync(from: simulation)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        steer(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        steer(touches)
    }

    private func steer(_ touches: Set<UITouch>) {
        guard director?.ticksSimulation != false else { return }
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

    /// Steer has no published velocity, so facing and the step use how fast `x` is changing.
    private func climberHorizontalSpeed(dt: Double) -> CGFloat {
        let x = simulation.climber.x
        if previousClimberX < 0 || dt <= 0 {
            previousClimberX = x
            return 0
        }
        let speed = (x - previousClimberX) / dt
        previousClimberX = x
        return CGFloat(speed)
    }

    private func layoutIfNeeded() {
        guard size.width > 1, size.height > 1 else { return }
        if !laidOut {
            backdrop.zPosition = 0
            addChild(backdrop)
            avalanche.fillColor = RidgeSK.color(0xE7EEF4, 0.92)
            avalanche.strokeColor = RidgeSK.color(0xD5E4EF, 0.4)
            avalanche.lineWidth = 0
            avalanche.zPosition = 3
            addChild(avalanche)
            let drift = SKEmitterNode()
            drift.particleTexture = RidgeDot.texture
            drift.particleBirthRate = 22
            drift.particleLifetime = 0.9
            drift.particleSpeed = 30
            drift.particleSpeedRange = 16
            drift.emissionAngle = .pi / 2
            drift.emissionAngleRange = 0.8
            drift.particleAlpha = 0.7
            drift.particleAlphaSpeed = -0.6
            drift.particleScale = 0.16
            drift.particleScaleRange = 0.08
            drift.particleColor = RidgeSK.color(0xF7FBFF)
            drift.particleColorBlendFactor = 1
            drift.zPosition = 3.2
            addChild(drift)
            avalancheDrift = drift
            playfield.zPosition = 4
            addChild(playfield)
            installFigure()
            playfield.addChild(climber)
            veil.zPosition = 14
            addChild(veil)
            flash.color = .white
            flash.alpha = 0
            flash.zPosition = 20
            flash.anchorPoint = .zero
            addChild(flash)
            laidOut = true
        }
        backdrop.sync(
            altitude: simulation.climber.y,
            weather: simulation.weather.kind,
            stage: simulation.stage,
            size: size
        )
        veil.sync(
            weather: simulation.weather.kind,
            size: size,
            lightning: CGFloat(simulation.lightningRemaining > 0 ? 1 : 0),
            time: lastTime
        )
        flash.size = size
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
                hazardNodes[id]?.pulse()
            case .hazardDefeated(let kind, let x, let y):
                let point = CGPoint(x: screenX(x), y: screenY(y))
                if kind.isRock {
                    emitFragments(at: point, weather: simulation.weather.kind)
                } else {
                    burst(at: point, color: RidgeSK.color(0xE7EEF4))
                }
            case .climberDamaged(_):
                figure?.noteHit()
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
            case .hazardSplit:
                break
            case .lightningFlash:
                flash.alpha = 0.62
                flash.color = .white
                flash.run(.fadeOut(withDuration: 0.18))
            case .hazardWarning, .weatherChanged, .charmChosen, .stageAdvanced, .bossAwakened, .defeated, .fusionAwakened, .setBonusReached, .cairnReached:
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
        backdrop.position = CGPoint(x: jitter.x * 0.35, y: jitter.y * 0.2)
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
            case .hazardWarning:
                SoundBoard.shared.play(.ui)
                haptics.play(.warning)
            case .hazardSplit:
                SoundBoard.shared.play(.hit)
            case .weatherChanged(let kind):
                director?.noteWeather(kind)
            case .lightningFlash:
                break
            }
        }
    }

    private func syncWorld(time: TimeInterval) {
        climber.position = CGPoint(x: screenX(simulation.climber.x), y: screenY(simulation.climber.y))
        climber.zPosition = 6
        let crest = max(CGFloat(0), screenY(simulation.avalancheY))
        avalanche.path = AvalancheArt.path(width: size.width, crest: crest, time: time)
        avalancheDrift?.position = CGPoint(x: size.width / 2, y: crest)
        avalancheDrift?.particlePositionRange = CGVector(dx: size.width, dy: 10)
        backdrop.sync(
            altitude: simulation.climber.y,
            weather: simulation.weather.kind,
            stage: simulation.stage,
            size: size
        )
        veil.sync(
            weather: simulation.weather.kind,
            size: size,
            lightning: CGFloat(simulation.lightningRemaining > 0 ? 1 : 0),
            time: time
        )

        var seen = Set<Int>()
        for hazard in simulation.hazards {
            seen.insert(hazard.id)
            let node = hazardNodes[hazard.id] ?? HazardVisual(kind: hazard.kind)
            if node.parent == nil {
                playfield.addChild(node)
                hazardNodes[hazard.id] = node
            }
            node.position = CGPoint(x: screenX(hazard.x), y: screenY(hazard.y))
            node.alpha = simulation.isConcealed(hazard) ? 0 : 1
            node.layout(radius: CGFloat(hazard.radius), pointsPerUnit: size.height / 560)
            node.apply(time: time, weather: simulation.weather.kind, velocityX: CGFloat(hazard.vx))
            if hazard.kind == .stormCrow {
                node.setFacing(flipX: hazard.vx < 0)
            }
        }
        let stale = hazardNodes.keys.filter { !seen.contains($0) }
        for id in stale {
            hazardNodes[id]?.removeFromParent()
            hazardNodes.removeValue(forKey: id)
        }
        syncOmens(time: time)
    }

    private func syncOmens(time: TimeInterval) {
        var seen = Set<Int>()
        for warning in simulation.warnings {
            seen.insert(warning.id)
            placeOmen(warning.id, kind: warning.kind, x: warning.x, time: time)
        }
        for hazard in simulation.hazards where simulation.isConcealed(hazard) && hazard.kind.isRock {
            let key = -hazard.id
            seen.insert(key)
            placeOmen(key, kind: hazard.kind, x: hazard.x, time: time)
        }
        for id in omenNodes.keys where !seen.contains(id) {
            omenNodes[id]?.removeFromParent()
            omenNodes.removeValue(forKey: id)
        }
    }

    private func placeOmen(_ id: Int, kind: HazardKind, x: Double, time: TimeInterval) {
        let node = omenNodes[id] ?? makeOmen(kind)
        if node.parent == nil {
            node.zPosition = 16
            addChild(node)
            omenNodes[id] = node
        }
        let pulse = 0.55 + 0.35 * abs(sin(time * 6))
        node.alpha = CGFloat(pulse)
        node.position = CGPoint(x: screenX(x), y: size.height - 36)
    }

    private func makeOmen(_ kind: HazardKind) -> SKShapeNode {
        let width: CGFloat = kind == .slab ? 34 : (kind == .boulder ? 20 : 12)
        let node = SKShapeNode(ellipseOf: CGSize(width: width, height: 8))
        node.fillColor = UIColor.black.withAlphaComponent(0.45)
        node.strokeColor = RidgeSK.color(0xF4E7D4, 0.8)
        node.lineWidth = 1
        return node
    }

    private func installFigure() {
        let portrait = ClimberRoster.profile(id: simulation.config.climberID).portrait
        let next: ClimberRendering = PaintedClimber(portrait: portrait) ?? ClimberFigure(portrait: portrait)
        figure = next
        climber.removeAllChildren()
        climber.addChild(next)
    }

    private func emitFragments(at point: CGPoint, weather: WeatherKind) {
        let textures = SpriteCatalog.fragmentTextures()
        guard !textures.isEmpty else {
            burst(at: point, color: RidgeSK.color(0xC4B8AA))
            return
        }
        let tint = WeatherSpriteTint.fragment(weather)
        let points = max(size.height / 560, 0.5)
        for index in 0..<8 {
            let holder = SKNode()
            holder.position = point
            holder.zPosition = 8
            let texture = textures[index % textures.count]
            let chip = SKSpriteNode(texture: texture)
            let side = CGFloat.random(in: 5...9) * points
            let aspect = max(texture.size().width, 1) / max(texture.size().height, 1)
            if aspect >= 1 {
                chip.size = CGSize(width: side, height: side / aspect)
            } else {
                chip.size = CGSize(width: side * aspect, height: side)
            }
            chip.color = tint.color
            chip.colorBlendFactor = tint.blend
            let shadow = SKShapeNode(ellipseOf: CGSize(width: side * 0.7, height: max(3, side * 0.22)))
            shadow.fillColor = UIColor.black.withAlphaComponent(0.28)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 1, y: -side * 0.32)
            shadow.zPosition = -1
            holder.addChild(shadow)
            holder.addChild(chip)
            playfield.addChild(holder)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 16...42)
            chip.run(.rotate(byAngle: CGFloat.random(in: -2.2...2.2), duration: 0.42))
            holder.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance * 0.55 - 6, duration: 0.42),
                    .fadeOut(withDuration: 0.42)
                ]),
                .removeFromParent()
            ]))
        }
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
        let burst = SKEmitterNode()
        burst.particleTexture = RidgeDot.texture
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
}
