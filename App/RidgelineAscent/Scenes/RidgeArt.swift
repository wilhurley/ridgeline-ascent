import RidgelineCore
import SpriteKit
import UIKit

enum RidgeArtCache {
    private static var textures: [String: SKTexture] = [:]

    static func sky(weather: WeatherKind, stage: StageID, size: CGSize) -> SKTexture {
        let key = "sky-\(weather.rawValue)-\(stage.rawValue)-\(Int(size.width))x\(Int(size.height))"
        if let cached = textures[key] { return cached }
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let pair = skyColors(weather: weather, stage: stage)
            let colors = [pair.top.cgColor, pair.horizon.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
            if weather == .clear {
                let sun = CGRect(x: size.width * 0.68, y: size.height * 0.58, width: 34, height: 34)
                UIColor(red: 0.93, green: 0.62, blue: 0.32, alpha: 0.95).setFill()
                context.cgContext.fillEllipse(in: sun)
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    static func ridge(layer: Int, width: CGFloat) -> SKTexture {
        let height: CGFloat = 480
        let key = "ridge-\(layer)-\(Int(width))"
        if let cached = textures[key] { return cached }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            drawRidge(layer: layer, in: context.cgContext, size: CGSize(width: width, height: height))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    private static func skyColors(weather: WeatherKind, stage: StageID) -> (top: UIColor, horizon: UIColor) {
        switch weather {
        case .clear:
            switch stage {
            case .screeApproach:
                return (RidgeSK.color(0x142033), RidgeSK.color(0xC4784A))
            case .iceShelf:
                return (RidgeSK.color(0x121C2E), RidgeSK.color(0x8A5A55))
            case .crowsEave, .theCornice:
                return (RidgeSK.color(0x0E1624), RidgeSK.color(0x5C4A62))
            }
        case .rain:
            return (RidgeSK.color(0x1A2836), RidgeSK.color(0x4A6274))
        case .blizzard:
            return (RidgeSK.color(0x8FA4B8), RidgeSK.color(0xE4EDF4))
        case .nightStorm:
            return (RidgeSK.color(0x070B12), RidgeSK.color(0x241838))
        }
    }

    private static func drawRidge(layer: Int, in context: CGContext, size: CGSize) {
        let crest = ridgeCrest(layer: layer, width: size.width, height: size.height)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: crest[0])
        for point in crest.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()

        let fill: UIColor
        let rim: UIColor
        let haze: CGFloat
        switch layer {
        case 0:
            fill = RidgeSK.color(0x9BB0C4, 0.95)
            rim = RidgeSK.color(0xC9D7E4, 0.55)
            haze = 0.28
        case 1:
            fill = RidgeSK.color(0x6E8498)
            rim = RidgeSK.color(0xF2F7FB, 0.7)
            haze = 0.18
        case 2:
            fill = RidgeSK.color(0x2C3A48)
            rim = RidgeSK.color(0xF4F7FA, 0.9)
            haze = 0.08
        default:
            fill = RidgeSK.color(0x171E28)
            rim = RidgeSK.color(0xE7EEF4, 0.85)
            haze = 0
        }
        context.setFillColor(fill.cgColor)
        context.addPath(path)
        context.fillPath()

        context.setStrokeColor(rim.cgColor)
        context.setLineWidth(layer >= 2 ? 3 : 2)
        context.beginPath()
        context.move(to: crest[0])
        for point in crest.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        if layer == 1 || layer == 2 {
            context.setFillColor(UIColor.white.withAlphaComponent(0.82).cgColor)
            for point in crest where Int(point.x) % 70 < 36 {
                let cap = CGRect(x: point.x - 16, y: point.y - 7, width: 32, height: 8)
                context.fill(cap)
            }
        }
        if haze > 0 {
            context.setFillColor(UIColor.white.withAlphaComponent(haze).cgColor)
            context.fill(CGRect(x: 0, y: size.height * 0.62, width: size.width, height: size.height * 0.38))
        }
        if layer >= 3 {
            context.setStrokeColor(RidgeSK.color(0xC4B29A, 0.7).cgColor)
            context.setLineWidth(5)
            context.beginPath()
            if let first = crest.first {
                context.move(to: CGPoint(x: first.x, y: first.y + 18))
            }
            for point in crest.dropFirst() {
                context.addLine(to: CGPoint(x: point.x, y: point.y + 18))
            }
            context.strokePath()
        }
    }

    static func haze(band: Int, width: CGFloat) -> SKTexture {
        let height: CGFloat = 160
        let key = "haze-\(band)-\(Int(width))"
        if let cached = textures[key] { return cached }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            let alpha: CGFloat = band == 0 ? 0.22 : (band == 1 ? 0.16 : 0.1)
            let color = UIColor(red: 0.78, green: 0.84, blue: 0.9, alpha: alpha)
            let colors = [UIColor.clear.cgColor, color.cgColor, UIColor.clear.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: height),
                options: []
            )
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }

    private static func ridgeCrest(layer: Int, width: CGFloat, height: CGFloat) -> [CGPoint] {
        let seeds: [[CGFloat]] = [
            [0.62, 0.48, 0.7, 0.4, 0.58, 0.36, 0.66, 0.5],
            [0.5, 0.34, 0.58, 0.28, 0.46, 0.22, 0.4],
            [0.38, 0.18, 0.42, 0.14, 0.3, 0.2, 0.36],
            [0.22, 0.08, 0.18, 0.05, 0.16, 0.1]
        ]
        let peaks = seeds[min(layer, seeds.count - 1)]
        var points: [CGPoint] = []
        let steps = peaks.count
        for index in 0...steps {
            let x = width * CGFloat(index) / CGFloat(steps)
            let peak = peaks[min(index, peaks.count - 1)]
            let y = height * (1 - peak)
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }
}

final class ParallaxRidge: SKNode {
    private var sky = SKSpriteNode()
    private var tiles: [(SKSpriteNode, SKSpriteNode, CGFloat)] = []
    private var builtWidth: CGFloat = 0
    private var skyKey = ""

    func sync(altitude: Double, weather: WeatherKind, stage: StageID, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        if abs(builtWidth - size.width) > 1 {
            rebuild(size: size)
        }
        let key = "\(weather.rawValue)-\(stage.rawValue)-\(Int(size.width))x\(Int(size.height))"
        if key != skyKey {
            sky.texture = RidgeArtCache.sky(weather: weather, stage: stage, size: size)
            sky.size = size
            skyKey = key
        }
        let span: CGFloat = 480
        let traveled = CGFloat(altitude)
        for (first, second, factor) in tiles {
            var scroll = (traveled * factor).truncatingRemainder(dividingBy: span)
            if scroll < 0 { scroll += span }
            first.position.y = -scroll
            second.position.y = span - scroll
        }
    }

    private func rebuild(size: CGSize) {
        removeAllChildren()
        tiles.removeAll()
        builtWidth = size.width
        skyKey = ""
        sky = SKSpriteNode()
        sky.anchorPoint = .zero
        sky.zPosition = 0
        addChild(sky)
        let factors: [CGFloat] = [0.05, 0.14, 0.28, 0.5]
        let hazeFactors: [CGFloat] = [0.09, 0.21, 0.38]
        for layer in 0..<4 {
            let texture = RidgeArtCache.ridge(layer: layer, width: size.width)
            let first = SKSpriteNode(texture: texture)
            let second = SKSpriteNode(texture: texture)
            for node in [first, second] {
                node.anchorPoint = .zero
                node.size = CGSize(width: size.width, height: 480)
                node.zPosition = CGFloat(layer + 1)
                addChild(node)
            }
            tiles.append((first, second, factors[layer]))
            if layer < hazeFactors.count {
                let hazeTexture = RidgeArtCache.haze(band: layer, width: size.width)
                let hazeA = SKSpriteNode(texture: hazeTexture)
                let hazeB = SKSpriteNode(texture: hazeTexture)
                for node in [hazeA, hazeB] {
                    node.anchorPoint = .zero
                    node.size = CGSize(width: size.width, height: 160)
                    node.position.y = 180
                    node.zPosition = CGFloat(layer) + 1.5
                    addChild(node)
                }
                tiles.append((hazeA, hazeB, hazeFactors[layer]))
            }
        }
    }
}

final class WeatherVeil: SKNode {
    private let dimmer = SKSpriteNode(color: .black, size: .zero)
    private let whiteout = SKSpriteNode(color: RidgeSK.color(0xE7EEF4), size: .zero)
    private var streaks: [SKShapeNode] = []
    private var snow: SKEmitterNode?
    private var built = false

    func sync(weather: WeatherKind, size: CGSize, lightning: CGFloat, time: TimeInterval) {
        guard size.width > 1 else { return }
        if !built { install(size: size) }
        dimmer.size = size
        whiteout.size = size
        let flash = min(1, max(0, lightning))
        switch weather {
        case .clear:
            dimmer.alpha = 0
            whiteout.alpha = 0
            snow?.isHidden = true
            streaks.forEach { $0.isHidden = true }
        case .rain:
            dimmer.alpha = 0.22 * (1 - flash * 0.8)
            whiteout.alpha = 0
            snow?.isHidden = true
            moveRain(size: size, time: time)
        case .blizzard:
            dimmer.alpha = 0.08
            whiteout.alpha = 0.3 * (1 - flash)
            snow?.isHidden = false
            streaks.forEach { $0.isHidden = true }
        case .nightStorm:
            dimmer.alpha = 0.42 * (1 - flash)
            whiteout.alpha = 0
            snow?.isHidden = true
            streaks.forEach { $0.isHidden = true }
        }
        if let snow {
            snow.particleBirthRate = weather == .blizzard ? 14 : 0
            snow.position = CGPoint(x: size.width / 2, y: size.height + 8)
            snow.particlePositionRange = CGVector(dx: size.width, dy: 8)
        }
    }

    private func install(size: CGSize) {
        built = true
        dimmer.anchorPoint = .zero
        dimmer.zPosition = 1
        addChild(dimmer)
        whiteout.anchorPoint = .zero
        whiteout.zPosition = 0
        addChild(whiteout)
        for index in 0..<16 {
            let streak = SKShapeNode(rectOf: CGSize(width: 2, height: 18), cornerRadius: 1)
            streak.fillColor = RidgeSK.color(0xD5E4EF, 0.45)
            streak.strokeColor = .clear
            streak.zRotation = -0.35
            streak.position = CGPoint(x: CGFloat(index) * 28, y: CGFloat((index * 53) % 800))
            streak.zPosition = 2
            addChild(streak)
            streaks.append(streak)
        }
        let emitter = SKEmitterNode()
        emitter.particleTexture = RidgeDot.texture
        emitter.particleBirthRate = 14
        emitter.particleLifetime = 4.2
        emitter.particleSpeed = 40
        emitter.particleSpeedRange = 18
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.4
        emitter.particleAlpha = 0.55
        emitter.particleScale = 0.08
        emitter.particleScaleRange = 0.05
        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 3
        addChild(emitter)
        snow = emitter
    }

    private func moveRain(size: CGSize, time: TimeInterval) {
        for (index, streak) in streaks.enumerated() {
            streak.isHidden = false
            let travel = CGFloat(time) * 280 + CGFloat(index * 47)
            let y = size.height - travel.truncatingRemainder(dividingBy: size.height + 40)
            let x = (CGFloat(index) * 26 + CGFloat(time) * 18).truncatingRemainder(dividingBy: size.width + 20)
            streak.position = CGPoint(x: x, y: y)
        }
    }
}

enum RidgeDot {
    static let texture: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()
}

/// Drawing seam for the climber. A sprite sheet can conform later and replace `ClimberFigure`
/// inside `RidgeScene` without touching the simulation.
protocol ClimberRendering: SKNode {
    func update(time: TimeInterval, gear: GearStyle)
}

/// Code-drawn climber. Swap this class for a sprite-sheet node that adopts `ClimberRendering`.
final class ClimberFigure: SKNode, ClimberRendering {
    private let portrait: ClimberPortrait
    private let body = SKNode()
    private let leftLeg = SKShapeNode()
    private let rightLeg = SKShapeNode()
    private let leftArm = SKShapeNode()
    private let rightArm = SKShapeNode()
    private let scarf = SKNode()
    private let axe = SKNode()
    private let flare = SKNode()
    private let hook = SKNode()
    private let hammer = SKNode()

    init(portrait: ClimberPortrait) {
        self.portrait = portrait
        super.init()
        build()
    }

    required init?(coder decoder: NSCoder) {
        fatalError("ClimberFigure is built in code")
    }

    func update(time: TimeInterval, gear: GearStyle) {
        let pace: CGFloat = portrait == .hauler ? 6.2 : 8.4
        let bob = CGFloat(sin(time * pace))
        body.position.y = bob * (portrait == .scout ? 2.2 : 1.4)
        leftLeg.zRotation = bob * 0.45
        rightLeg.zRotation = -bob * 0.45
        leftArm.zRotation = -bob * 0.55
        rightArm.zRotation = bob * 0.35
        scarf.position = CGPoint(x: CGFloat(sin(time * 6.5)) * 4, y: CGFloat(cos(time * 6.5)) * 1.5)
        axe.isHidden = gear != .iceAxe || portrait == .hauler
        hammer.isHidden = !(gear == .iceAxe && portrait == .hauler)
        flare.isHidden = gear != .flare
        hook.isHidden = gear != .ropeHook
    }

    private func build() {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: portrait == .hauler ? 36 : 26, height: 8))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -2
        addChild(shadow)

        addChild(body)
        let slim = portrait == .scout
        let wide = portrait == .hauler
        let coat: UIColor
        switch portrait {
        case .guide: coat = RidgeSK.color(0xE07A3D)
        case .scout: coat = RidgeSK.color(0x2F8F9D)
        case .hauler: coat = RidgeSK.color(0x8C3A2F)
        }
        let torsoWidth: CGFloat = wide ? 22 : (slim ? 12 : 16)
        let torso = SKShapeNode(rectOf: CGSize(width: torsoWidth, height: wide ? 24 : 22), cornerRadius: 4)
        torso.fillColor = coat
        torso.strokeColor = RidgeSK.color(0xF4E7D4, 0.8)
        torso.lineWidth = 1.5
        torso.position = CGPoint(x: 0, y: 14)
        body.addChild(torso)

        if wide {
            let pack = SKShapeNode(rectOf: CGSize(width: 16, height: 20), cornerRadius: 3)
            pack.fillColor = RidgeSK.color(0x4A2E24)
            pack.strokeColor = RidgeSK.color(0xC4B29A)
            pack.lineWidth = 1
            pack.position = CGPoint(x: -2, y: 16)
            pack.zPosition = -1
            body.addChild(pack)
        }

        let head = SKShapeNode(circleOfRadius: slim ? 5 : 6)
        head.fillColor = RidgeSK.color(0xE7C7A8)
        head.strokeColor = coat
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: wide ? 30 : 28)
        body.addChild(head)

        addLimb(leftLeg, x: slim ? -3 : -4, color: RidgeSK.color(0x1B2430))
        addLimb(rightLeg, x: slim ? 3 : 4, color: RidgeSK.color(0x1B2430))
        addArm(leftArm, x: -torsoWidth * 0.55, color: coat)
        addArm(rightArm, x: torsoWidth * 0.4, color: coat)

        if portrait == .scout {
            for index in 0..<3 {
                let tail = SKShapeNode(rectOf: CGSize(width: 8, height: 3), cornerRadius: 1)
                tail.fillColor = RidgeSK.color(0xF2E2C4)
                tail.strokeColor = .clear
                tail.position = CGPoint(x: 8 + CGFloat(index) * 5, y: CGFloat(index) * -2)
                scarf.addChild(tail)
            }
            scarf.position = CGPoint(x: 0, y: 24)
            scarf.zPosition = 2
            body.addChild(scarf)
        }

        buildAxe()
        buildFlare()
        buildHook()
        buildHammer()
        for tool in [axe, flare, hook, hammer] {
            tool.position = CGPoint(x: wide ? 12 : 9, y: 16)
            tool.zPosition = 3
            body.addChild(tool)
        }
    }

    private func addArm(_ node: SKShapeNode, x: CGFloat, color: UIColor) {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: portrait == .scout ? 2 : 0, y: -11))
        node.path = path
        node.strokeColor = color
        node.lineWidth = portrait == .hauler ? 5 : (portrait == .scout ? 2.5 : 3)
        node.lineCap = .round
        node.position = CGPoint(x: x, y: 20)
        body.addChild(node)
    }

    private func addLimb(_ node: SKShapeNode, x: CGFloat, color: UIColor) {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: -12))
        node.path = path
        node.strokeColor = color
        node.lineWidth = portrait == .hauler ? 4 : 3
        node.lineCap = .round
        node.position = CGPoint(x: x, y: 6)
        addChild(node)
    }

    private func buildAxe() {
        let shaft = line(from: .zero, to: CGPoint(x: 10, y: 16), color: RidgeSK.color(0xC4B29A), width: 2)
        let pick = line(from: CGPoint(x: 8, y: 14), to: CGPoint(x: 16, y: 18), color: RidgeSK.color(0xE7EEF4), width: 2)
        axe.addChild(shaft)
        axe.addChild(pick)
    }

    private func buildFlare() {
        let gun = SKShapeNode(rectOf: CGSize(width: 12, height: 4), cornerRadius: 1)
        gun.fillColor = RidgeSK.color(0xE07A3D)
        gun.strokeColor = .clear
        gun.position = CGPoint(x: 6, y: 8)
        flare.addChild(gun)
    }

    private func buildHook() {
        hook.addChild(line(from: .zero, to: CGPoint(x: 14, y: 8), color: RidgeSK.color(0xD4A054), width: 2))
        hook.addChild(line(from: CGPoint(x: 14, y: 8), to: CGPoint(x: 10, y: 14), color: RidgeSK.color(0xD4A054), width: 2))
    }

    private func buildHammer() {
        hammer.addChild(line(from: .zero, to: CGPoint(x: 8, y: 14), color: RidgeSK.color(0x6B4A32), width: 3))
        let head = SKShapeNode(rectOf: CGSize(width: 14, height: 6), cornerRadius: 1)
        head.fillColor = RidgeSK.color(0x3A3532)
        head.strokeColor = RidgeSK.color(0xE7EEF4, 0.6)
        head.position = CGPoint(x: 12, y: 16)
        hammer.addChild(head)
    }

    private func line(from start: CGPoint, to end: CGPoint, color: UIColor, width: CGFloat) -> SKShapeNode {
        let node = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        node.path = path
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        return node
    }
}

enum AvalancheArt {
    static func path(width: CGFloat, crest: CGFloat, time: TimeInterval) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        let steps = 14
        for index in 0...steps {
            let x = width * CGFloat(index) / CGFloat(steps)
            let wave = sin(time * 2.6 + Double(index) * 0.7) * 7
            let puff = sin(time * 4.1 + Double(index) * 1.3) * 4
            path.addLine(to: CGPoint(x: x, y: crest + CGFloat(wave + puff)))
        }
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}
