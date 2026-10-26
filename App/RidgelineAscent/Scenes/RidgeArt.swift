import RidgelineCore
import CoreImage
import SpriteKit
import UIKit

/// Painted ridge backgrounds. One catalog image per weather, softened once and reused.
enum BackdropArt {
    static let overscan: CGFloat = 1.08

    private static var textures: [WeatherKind: SKTexture] = [:]
    private static var vignettes: [String: SKTexture] = [:]
    private static let context = CIContext(options: nil)

    static func warm() {
        for weather in WeatherKind.allCases {
            _ = texture(for: weather)
        }
    }

    static func texture(for weather: WeatherKind) -> SKTexture {
        if let cached = textures[weather] { return cached }
        let image = UIImage(named: assetName(weather)) ?? fallbackImage(weather)
        let softened = soften(image)
        let texture = SKTexture(image: softened)
        texture.filteringMode = .linear
        textures[weather] = texture
        return texture
    }

    static func coverSize(for texture: SKTexture, screen: CGSize) -> CGSize {
        let tex = texture.size()
        let texW = tex.width > 1 ? tex.width : 720
        let texH = tex.height > 1 ? tex.height : 1280
        let scale = max(screen.width / texW, screen.height / texH) * overscan
        return CGSize(width: texW * scale, height: texH * scale)
    }

    /// Soft darkening over the bright sky, where hazards first appear, feathered into the slope.
    static func vignette(size: CGSize) -> SKTexture {
        let key = "\(Int(size.width))x\(Int(size.height))"
        if let cached = vignettes[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let vertical = [
                UIColor.black.withAlphaComponent(0.46).cgColor,
                UIColor.black.withAlphaComponent(0.36).cgColor,
                UIColor.black.withAlphaComponent(0.18).cgColor,
                UIColor.black.withAlphaComponent(0.12).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: vertical, locations: [0, 0.42, 0.68, 1]) {
                cg.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
            let edge = [
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0).cgColor,
                UIColor.black.withAlphaComponent(0.30).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: edge, locations: [0, 0.45, 1]) {
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
                let radius = max(size.width, size.height) * 0.75
                cg.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: []
                )
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        vignettes[key] = texture
        return texture
    }

    private static func assetName(_ weather: WeatherKind) -> String {
        switch weather {
        case .clear: return "backdrop_clear"
        case .rain: return "backdrop_rain"
        case .blizzard: return "backdrop_blizzard"
        case .nightStorm: return "backdrop_night"
        }
    }

    private static func soften(_ image: UIImage) -> UIImage {
        guard let source = CIImage(image: image),
              let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        filter.setValue(source.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(4.0, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: source.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private static func fallbackImage(_ weather: WeatherKind) -> UIImage {
        let size = CGSize(width: 720, height: 1280)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let top: UIColor
            let horizon: UIColor
            let ground: UIColor
            switch weather {
            case .clear:
                top = RidgeSK.color(0x142033)
                horizon = RidgeSK.color(0xC4784A)
                ground = RidgeSK.color(0x1A242E)
            case .rain:
                top = RidgeSK.color(0x3A4550)
                horizon = RidgeSK.color(0x5C6A74)
                ground = RidgeSK.color(0x243038)
            case .blizzard:
                top = RidgeSK.color(0xC5D0D8)
                horizon = RidgeSK.color(0x8FA0AE)
                ground = RidgeSK.color(0x3E4C58)
            case .nightStorm:
                top = RidgeSK.color(0x10182C)
                horizon = RidgeSK.color(0x243048)
                ground = RidgeSK.color(0x10141C)
            }
            let colors = [top.cgColor, horizon.cgColor, ground.cgColor, ground.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.34, 0.58, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}

/// Full-screen painted backdrop, plus a ridge edge under the climber.
/// The painting drifts a few points as altitude climbs and never shows its edge.
final class ParallaxRidge: SKNode {
    private let base = SKSpriteNode()
    private let incoming = SKSpriteNode()
    private let shade = SKSpriteNode()
    private let ridge = SKShapeNode()
    private var shown: WeatherKind?
    private var fadingTo: WeatherKind?
    private var builtSize = CGSize.zero

    func sync(altitude: Double, weather: WeatherKind, stage _: StageID, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        if builtSize == .zero {
            install()
            BackdropArt.warm()
        }
        if abs(builtSize.width - size.width) > 1 || abs(builtSize.height - size.height) > 1 {
            builtSize = size
            shade.texture = BackdropArt.vignette(size: size)
            shade.size = size
        }
        if shown == nil {
            base.texture = BackdropArt.texture(for: weather)
            shown = weather
        } else if weather != shown, weather != fadingTo {
            beginFade(to: weather)
        }
        let texture = base.texture ?? BackdropArt.texture(for: weather)
        let fitted = BackdropArt.coverSize(for: texture, screen: size)
        let slack = max(CGFloat(0), (fitted.height - size.height) * 0.5)
        let drift = slack * CGFloat(tanh(altitude / 2800))
        let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.5 - drift)
        for node in [base, incoming] {
            node.size = fitted
            node.position = origin
        }
        updateRidge(size: size, altitude: CGFloat(altitude))
    }

    private func install() {
        for node in [base, incoming] {
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            addChild(node)
        }
        base.zPosition = 0
        incoming.zPosition = 1
        incoming.alpha = 0
        shade.anchorPoint = .zero
        shade.zPosition = 2
        addChild(shade)
        ridge.fillColor = UIColor.black.withAlphaComponent(0.42)
        ridge.strokeColor = .clear
        ridge.lineWidth = 0
        ridge.zPosition = 3
        addChild(ridge)
    }

    private func beginFade(to weather: WeatherKind) {
        incoming.removeAllActions()
        if let fadingTo, fadingTo != weather, incoming.alpha > 0.45, let texture = incoming.texture {
            base.texture = texture
            shown = fadingTo
        }
        fadingTo = weather
        incoming.texture = BackdropArt.texture(for: weather)
        incoming.alpha = 0
        incoming.run(.fadeIn(withDuration: 0.7)) { [weak self] in
            guard let self, self.fadingTo == weather else { return }
            self.base.texture = self.incoming.texture
            self.incoming.alpha = 0
            self.shown = weather
            self.fadingTo = nil
        }
    }

    private func updateRidge(size: CGSize, altitude: CGFloat) {
        let crest = size.height * 0.34 - 12
        let path = CGMutablePath()
        let steps = 24
        var top: [CGPoint] = []
        var bottom: [CGPoint] = []
        for index in 0...steps {
            let x = size.width * CGFloat(index) / CGFloat(steps)
            let wave = sin((x / size.width) * .pi * 2 + altitude * 0.004) * 5
            let y = crest + CGFloat(wave)
            top.append(CGPoint(x: x, y: y))
            bottom.append(CGPoint(x: x, y: y - 22))
        }
        path.move(to: top[0])
        for point in top.dropFirst() {
            path.addLine(to: point)
        }
        for point in bottom.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        ridge.path = path
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
            dimmer.alpha = 0
            whiteout.alpha = 0
            snow?.isHidden = true
            moveRain(size: size, time: time)
        case .blizzard:
            dimmer.alpha = 0
            whiteout.alpha = 0.08 * (1 - flash)
            snow?.isHidden = false
            streaks.forEach { $0.isHidden = true }
        case .nightStorm:
            dimmer.alpha = 0
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
