import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

public struct ClimberState: Equatable {
    public var x: Double
    public var y: Double
    public var health: Double
    public var maxHealth: Double
    public var alive: Bool
}

public struct HazardState: Equatable, Identifiable {
    public let id: Int
    public var kind: HazardKind
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var health: Double
    public var maxHealth: Double
    public var radius: Double
    public var contactDamage: Double
    public var contactCooldown: Double
}

public enum DefeatCause: String, Equatable {
    case avalanche
    case struckDown

    public var epitaph: String {
        switch self {
        case .avalanche:
            return "The avalanche caught your heels."
        case .struckDown:
            return "The ridge struck you down."
        }
    }
}

public enum RunPhase: Equatable {
    case climbing
    case cairn(offers: [CharmDefinition])
    case boss
    case defeated(DefeatCause)
    case summit

    public var isPlaying: Bool {
        switch self {
        case .climbing, .boss:
            return true
        case .cairn, .defeated, .summit:
            return false
        }
    }
}

public enum SimEffect: Equatable {
    case attackFired(style: GearStyle, fromX: Double, fromY: Double, toX: Double, toY: Double)
    case hazardDamaged(id: Int)
    case hazardDefeated(kind: HazardKind, x: Double, y: Double)
    case climberDamaged(amount: Double)
    case screenShake(amount: Double)
    case cairnReached
    case charmChosen(id: String)
    case fusionAwakened(name: String)
    case setBonusReached(name: String)
    case stageAdvanced(StageID)
    case bossAwakened
    case defeated(DefeatCause)
    case summitReached
    case revived
}

/// SpriteKit-free ascent. Call `setSteer` from a drag and `tick` from the frame loop.
/// Cairn, defeat, and summit phases ignore `tick` until the caller chooses or revives.
public final class RidgeSimulation {
    public let config: SimConfig
    public let catalog: CharmCatalog

    public private(set) var phase: RunPhase = .climbing
    public private(set) var climber: ClimberState
    public private(set) var avalancheY: Double
    public private(set) var hazards: [HazardState] = []
    public private(set) var ownedCharms: [CharmDefinition] = []
    public private(set) var activeFusions: [FusionDefinition] = []
    public private(set) var activeSetBonuses: [SetBonusDefinition] = []
    public private(set) var loadout: Loadout
    public private(set) var stage: StageID = .screeApproach
    public private(set) var score = RunScore()
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var stageElapsed: TimeInterval = 0
    public private(set) var bossElapsed: TimeInterval = 0

    private var rng: SplitMix64
    private var steerTargetX: Double
    private var effects: [SimEffect] = []
    private var nextHazardID = 1
    private var spawnTimer = 0.55
    private var attackCooldown = 0.0
    private var invulnerability = 0.0
    private var hitSlowRemaining = 0.0
    private var timeSinceCairn = 0.0
    private var extraAvalancheSpeed: Double
    private var bossSpawned = false

    public init(config: SimConfig = .standard, catalog: CharmCatalog = .starter) {
        self.config = config
        self.catalog = catalog
        self.rng = SplitMix64(seed: config.seed)
        let mid = config.ridgeWidth * 0.5
        self.steerTargetX = mid
        self.extraAvalancheSpeed = config.extraAvalancheSpeed
        self.climber = ClimberState(
            x: mid,
            y: 0,
            health: config.baseMaxHealth,
            maxHealth: config.baseMaxHealth,
            alive: true
        )
        self.avalancheY = -config.startingLead
        self.loadout = Loadout.resolve(config: config, effects: [])
        refreshLoadout(announceNew: false)
        climber.health = loadout.maxHealth
        climber.maxHealth = loadout.maxHealth
    }

    public var lead: Double { climber.y - avalancheY }

    /// `normalizedX` is 0 at the left edge of the screen and 1 at the right.
    /// The climber walks toward that lane. Dragging anywhere on screen is enough.
    public func setSteer(normalizedX: Double) {
        let clamped = min(1, max(0, normalizedX))
        let margin = 18.0
        let span = max(0, config.ridgeWidth - margin * 2)
        steerTargetX = margin + clamped * span
    }

    public func tick(dt: Double) {
        guard dt.isFinite, dt > 0 else { return }
        // A stalled frame can be long; keep it bounded so one hitch cannot
        // spin for an unbounded number of substeps. Callers that need more
        // than a minute should tick in slices.
        var left = min(dt, 60)
        let maxStep = 1.0 / 60.0
        while left > 0.0000001 {
            let step = min(maxStep, left)
            stepOnce(dt: step)
            left -= step
            if !phase.isPlaying {
                break
            }
        }
    }

    @discardableResult
    public func chooseCharm(id: String) -> Bool {
        guard case .cairn(let offers) = phase else { return false }
        guard let charm = offers.first(where: { $0.id == id }) else { return false }
        let beforeMax = loadout.maxHealth
        let beforeBonusIDs = Set(activeSetBonuses.map(\.id))
        let beforeFusionIDs = Set(activeFusions.map(\.id))
        ownedCharms.append(charm)
        score.cairnsClaimed += 1
        refreshLoadout(announceNew: false)
        let gainedMax = max(0, loadout.maxHealth - beforeMax)
        climber.maxHealth = loadout.maxHealth
        climber.health = min(loadout.maxHealth, climber.health + gainedMax + loadout.healOnCairn)
        phase = .climbing
        effects.append(.charmChosen(id: charm.id))
        announceNewModifiers(previousBonuses: beforeBonusIDs, previousFusions: beforeFusionIDs)
        effects.append(.screenShake(amount: 0.12))
        return true
    }

    /// Pulls the avalanche back and clears the immediate rocks. The session
    /// decides whether a revive is still available.
    public func revive() {
        guard case .defeated = phase else { return }
        climber.alive = true
        climber.maxHealth = loadout.maxHealth
        climber.health = max(climber.health, loadout.maxHealth * 0.7)
        let restored = max(120, config.minLead + 40)
        avalancheY = climber.y - restored
        hitSlowRemaining = 0
        invulnerability = 1.4
        hazards.removeAll { hazard in
            hazard.kind != .corniceTyrant && distance(hazard, climber) < 170
        }
        if stage == .theCornice {
            if !hazards.contains(where: { $0.kind == .corniceTyrant }) {
                spawnBoss()
            }
            phase = .boss
        } else {
            phase = .climbing
        }
        effects.append(.revived)
        effects.append(.screenShake(amount: 0.35))
    }

    public func drainEffects() -> [SimEffect] {
        let current = effects
        effects.removeAll(keepingCapacity: true)
        return current
    }

    func testingSpawnHazard(
        kind: HazardKind,
        x: Double,
        y: Double,
        health: Double = 30,
        radius: Double = 12,
        contactDamage: Double = 10
    ) -> Int {
        let id = nextHazardID
        nextHazardID += 1
        hazards.append(HazardState(
            id: id,
            kind: kind,
            x: x,
            y: y,
            vx: 0,
            vy: 0,
            health: health,
            maxHealth: health,
            radius: radius,
            contactDamage: contactDamage,
            contactCooldown: 0
        ))
        return id
    }

    func testingGrantCharm(id: String) -> Bool {
        guard let charm = catalog.charm(id: id) else { return false }
        guard !ownedCharms.contains(where: { $0.id == id }) else { return false }
        let beforeBonusIDs = Set(activeSetBonuses.map(\.id))
        let beforeFusionIDs = Set(activeFusions.map(\.id))
        let beforeMax = loadout.maxHealth
        ownedCharms.append(charm)
        refreshLoadout(announceNew: false)
        let gainedMax = max(0, loadout.maxHealth - beforeMax)
        climber.maxHealth = loadout.maxHealth
        climber.health = min(loadout.maxHealth, climber.health + gainedMax)
        announceNewModifiers(previousBonuses: beforeBonusIDs, previousFusions: beforeFusionIDs)
        return true
    }

    func testingSetHealth(_ value: Double) {
        climber.health = min(loadout.maxHealth, max(0, value))
        climber.maxHealth = loadout.maxHealth
    }

    func testingSetExtraAvalancheSpeed(_ value: Double) {
        extraAvalancheSpeed = value
    }

    private func stepOnce(dt: Double) {
        guard phase.isPlaying else { return }
        elapsed += dt
        if invulnerability > 0 { invulnerability = max(0, invulnerability - dt) }
        if hitSlowRemaining > 0 { hitSlowRemaining = max(0, hitSlowRemaining - dt) }

        integrateClimber(dt: dt)
        integrateAvalanche(dt: dt)
        score.altitude = climber.y
        if lead <= 0 {
            defeat(.avalanche)
            return
        }

        if stage == .theCornice {
            bossElapsed += dt
        } else {
            stageElapsed += dt
        }

        updateSpawns(dt: dt)
        updateHazards(dt: dt)
        resolveContacts()
        if !phase.isPlaying { return }
        resolveAttacks(dt: dt)
        if !phase.isPlaying { return }
        updateStageClock()
        if !phase.isPlaying { return }
        updateCairnClock(dt: dt)
    }

    private func integrateClimber(dt: Double) {
        let slow = hitSlowRemaining > 0 ? config.hitSlowMultiplier : 1
        climber.y += loadout.climbSpeed * slow * dt
        let dx = steerTargetX - climber.x
        let step = config.lateralSpeed * dt
        if abs(dx) <= step {
            climber.x = steerTargetX
        } else {
            climber.x += (dx > 0 ? step : -step)
        }
        let margin = 18.0
        climber.x = min(config.ridgeWidth - margin, max(margin, climber.x))
    }

    private func integrateAvalanche(dt: Double) {
        let target = Pressure.targetLead(
            config: config,
            stage: stage,
            climbTime: elapsed,
            bossTime: bossElapsed
        )
        let sample = DifficultyCurve.sample(stage: stage, timeInStage: currentStageTime, climbTime: elapsed)
        let error = lead - target
        var speed = loadout.climbSpeed
            + error * config.leadTrackGain
            + sample.avalancheBonus
            + extraAvalancheSpeed
            - loadout.avalancheDrag
        if speed < 0 { speed = 0 }
        avalancheY += speed * dt
    }

    private var currentStageTime: Double {
        stage == .theCornice ? bossElapsed : stageElapsed
    }

    private func updateSpawns(dt: Double) {
        guard config.spawnsEnabled else { return }
        spawnTimer -= dt
        guard spawnTimer <= 0 else { return }
        let sample = DifficultyCurve.sample(stage: stage, timeInStage: currentStageTime, climbTime: elapsed)
        spawnTimer = sample.spawnInterval
        let livingAdds = hazards.filter { $0.kind != .corniceTyrant }.count
        guard livingAdds < 24 else { return }
        guard let kind = sample.allowedKinds.randomElement(using: &rng) else { return }
        spawnAdd(kind: kind, sample: sample)
    }

    private func spawnAdd(kind: HazardKind, sample: DifficultySample) {
        let margin = 22.0
        let x = margin + rng.nextUnit() * (config.ridgeWidth - margin * 2)
        switch kind {
        case .fallingRock:
            appendHazard(
                kind: kind,
                x: x,
                y: climber.y + config.spawnAhead,
                vx: 0,
                vy: -sample.hazardSpeed,
                health: sample.hazardHealth,
                radius: 13,
                contactDamage: sample.contactDamage
            )
        case .iceWraith:
            appendHazard(
                kind: kind,
                x: x,
                y: climber.y + config.spawnAhead * 0.72,
                vx: 0,
                vy: -36,
                health: sample.hazardHealth * 1.35,
                radius: 15,
                contactDamage: sample.contactDamage + 2
            )
        case .stormCrow:
            let fromLeft = rng.nextUnit() < 0.5
            appendHazard(
                kind: kind,
                x: fromLeft ? -16 : config.ridgeWidth + 16,
                y: climber.y + 160,
                vx: fromLeft ? 150 : -150,
                vy: -18,
                health: sample.hazardHealth * 0.8,
                radius: 12,
                contactDamage: sample.contactDamage
            )
        case .corniceTyrant:
            break
        }
    }

    private func spawnBoss() {
        bossSpawned = true
        let sample = DifficultyCurve.sample(stage: .theCornice, timeInStage: 0, climbTime: elapsed)
        appendHazard(
            kind: .corniceTyrant,
            x: config.ridgeWidth * 0.5,
            y: climber.y + config.bossLeash,
            vx: 0,
            vy: 0,
            health: config.bossHealth,
            radius: 34,
            contactDamage: sample.contactDamage + 6
        )
        effects.append(.bossAwakened)
        effects.append(.screenShake(amount: 0.55))
    }

    private func appendHazard(
        kind: HazardKind,
        x: Double,
        y: Double,
        vx: Double,
        vy: Double,
        health: Double,
        radius: Double,
        contactDamage: Double
    ) {
        let id = nextHazardID
        nextHazardID += 1
        hazards.append(HazardState(
            id: id,
            kind: kind,
            x: x,
            y: y,
            vx: vx,
            vy: vy,
            health: health,
            maxHealth: health,
            radius: radius,
            contactDamage: contactDamage,
            contactCooldown: 0
        ))
    }

    private func updateHazards(dt: Double) {
        for index in hazards.indices {
            if hazards[index].kind == .corniceTyrant {
                let sweep = ridgeSin(bossElapsed * 1.35) * config.ridgeWidth * 0.30
                hazards[index].x = config.ridgeWidth * 0.5 + sweep
                hazards[index].y = climber.y + config.bossLeash
            } else if hazards[index].kind == .iceWraith {
                let toward = climber.x - hazards[index].x
                hazards[index].vx = toward >= 0 ? 78 : -78
                hazards[index].x += hazards[index].vx * dt
                hazards[index].y += hazards[index].vy * dt
            } else {
                hazards[index].x += hazards[index].vx * dt
                hazards[index].y += hazards[index].vy * dt
            }
            if hazards[index].contactCooldown > 0 {
                hazards[index].contactCooldown = max(0, hazards[index].contactCooldown - dt)
            }
        }
        hazards.removeAll { hazard in
            guard hazard.kind != .corniceTyrant else { return false }
            if hazard.y < climber.y - 200 { return true }
            if hazard.y < avalancheY - 30 { return true }
            if hazard.x < -80 || hazard.x > config.ridgeWidth + 80 { return true }
            return false
        }
    }

    private func resolveContacts() {
        var removeIDs = Set<Int>()
        for index in hazards.indices {
            let hazard = hazards[index]
            guard distance(hazard, climber) <= hazard.radius + config.climberRadius else { continue }
            guard invulnerability <= 0, hazard.contactCooldown <= 0 else { continue }
            let amount = hazard.contactDamage * (1 - loadout.armor)
            climber.health -= amount
            invulnerability = config.hitInvulnerability
            hitSlowRemaining = config.hitSlowDuration
            effects.append(.climberDamaged(amount: amount))
            effects.append(.screenShake(amount: 0.48))
            if hazard.kind == .corniceTyrant {
                hazards[index].contactCooldown = 0.85
            } else {
                removeIDs.insert(hazard.id)
            }
            if climber.health <= 0 {
                climber.health = 0
                climber.alive = false
                hazards.removeAll { removeIDs.contains($0.id) }
                defeat(.struckDown)
                return
            }
        }
        if !removeIDs.isEmpty {
            hazards.removeAll { removeIDs.contains($0.id) }
        }
    }

    private func resolveAttacks(dt: Double) {
        attackCooldown -= dt
        guard attackCooldown <= 0 else { return }
        attackCooldown = 0
        let aimed = hazards.map { hazard in
            (hazard, distance(hazard, climber))
        }
        .filter { $0.1 <= loadout.range }
        .sorted { $0.1 < $1.1 }
        .prefix(loadout.targets)
        guard !aimed.isEmpty else { return }

        attackCooldown = loadout.cooldown
        var removeIDs = Set<Int>()
        var defeatedBoss = false
        for entry in aimed {
            guard let index = hazards.firstIndex(where: { $0.id == entry.0.id }) else { continue }
            let amount = loadout.damage + loadout.burnDamage
            hazards[index].health -= amount
            effects.append(.attackFired(
                style: loadout.gearStyle,
                fromX: climber.x,
                fromY: climber.y,
                toX: hazards[index].x,
                toY: hazards[index].y
            ))
            effects.append(.hazardDamaged(id: entry.0.id))
            if hazards[index].health <= 0 {
                let killed = hazards[index]
                removeIDs.insert(killed.id)
                score.hazardsDefeated += 1
                effects.append(.hazardDefeated(kind: killed.kind, x: killed.x, y: killed.y))
                effects.append(.screenShake(amount: killed.kind == .corniceTyrant ? 0.85 : 0.2))
                if killed.kind == .corniceTyrant {
                    defeatedBoss = true
                }
            } else {
                effects.append(.screenShake(amount: 0.08))
            }
        }
        if !removeIDs.isEmpty {
            hazards.removeAll { removeIDs.contains($0.id) }
        }
        if defeatedBoss {
            score.summitReached = true
            phase = .summit
            effects.append(.summitReached)
        }
    }

    private func defeat(_ cause: DefeatCause) {
        climber.alive = false
        phase = .defeated(cause)
        effects.append(.defeated(cause))
        effects.append(.screenShake(amount: cause == .avalanche ? 1 : 0.75))
    }

    private func updateStageClock() {
        guard stage != .theCornice else { return }
        let duration = config.durations[stage.rawValue - 1]
        guard stageElapsed >= duration else { return }
        score.stagesCleared += 1
        stageElapsed = 0
        if stage == .crowsEave {
            stage = .theCornice
            phase = .boss
            bossElapsed = 0
            hazards.removeAll { $0.kind != .corniceTyrant }
            effects.append(.stageAdvanced(.theCornice))
            if !bossSpawned {
                spawnBoss()
            }
        } else if let next = stage.next {
            stage = next
            effects.append(.stageAdvanced(next))
            effects.append(.screenShake(amount: 0.22))
        }
    }

    private func updateCairnClock(dt: Double) {
        guard phase == .climbing else { return }
        timeSinceCairn += dt
        guard timeSinceCairn >= config.cairnInterval else { return }
        timeSinceCairn = 0
        let owned = Set(ownedCharms.map(\.id))
        let offers = catalog.offers(count: 3, excluding: owned, rng: &rng)
        guard !offers.isEmpty else { return }
        phase = .cairn(offers: offers)
        effects.append(.cairnReached)
        effects.append(.screenShake(amount: 0.16))
    }

    private func refreshLoadout(announceNew: Bool) {
        let previousBonuses = Set(activeSetBonuses.map(\.id))
        let previousFusions = Set(activeFusions.map(\.id))
        var collected: [CharmEffect] = []
        for charm in ownedCharms {
            collected.append(contentsOf: charm.effects)
        }
        let counts = Dictionary(grouping: ownedCharms, by: \.tag).mapValues(\.count)
        let bonuses = catalog.setBonuses
            .filter { (counts[$0.tag] ?? 0) >= $0.threshold }
            .sorted { lhs, rhs in
                if lhs.tag.rawValue != rhs.tag.rawValue { return lhs.tag.rawValue < rhs.tag.rawValue }
                return lhs.threshold < rhs.threshold
            }
        for bonus in bonuses {
            collected.append(contentsOf: bonus.effects)
        }
        let ownedIDs = Set(ownedCharms.map(\.id))
        let fusions = catalog.fusions
            .filter { $0.isUnlocked(owned: ownedIDs) }
            .sorted { $0.id < $1.id }
        for fusion in fusions {
            collected.append(contentsOf: fusion.effects)
        }
        activeSetBonuses = bonuses
        activeFusions = fusions
        loadout = Loadout.resolve(config: config, effects: collected)
        if announceNew {
            announceNewModifiers(previousBonuses: previousBonuses, previousFusions: previousFusions)
        }
    }

    private func announceNewModifiers(previousBonuses: Set<String>, previousFusions: Set<String>) {
        for bonus in activeSetBonuses where !previousBonuses.contains(bonus.id) {
            effects.append(.setBonusReached(name: bonus.name))
        }
        for fusion in activeFusions where !previousFusions.contains(fusion.id) {
            effects.append(.fusionAwakened(name: fusion.name))
        }
    }

    private func distance(_ hazard: HazardState, _ climber: ClimberState) -> Double {
        let dx = hazard.x - climber.x
        let dy = hazard.y - climber.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

private extension Array where Element == HazardKind {
    func randomElement(using rng: inout SplitMix64) -> HazardKind? {
        guard !isEmpty else { return nil }
        return self[rng.nextInt(upperBound: count)]
    }
}

private func ridgeSin(_ value: Double) -> Double {
    #if canImport(Darwin)
    return Darwin.sin(value)
    #elseif canImport(Glibc)
    return Glibc.sin(value)
    #elseif canImport(Musl)
    return Musl.sin(value)
    #else
    return 0
    #endif
}
