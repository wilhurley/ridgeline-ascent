import AVFoundation

enum SoundCue: String, CaseIterable {
    case axe
    case flare
    case hook
    case hit
    case hurt
    case cairn
    case charm
    case death
    case summit
    case ui
}

/// Plays short placeholder tones bundled with the app.
/// Swap the wav files for scored audio without changing call sites.
final class SoundBoard {
    static let shared = SoundBoard()

    private var players: [SoundCue: AVAudioPlayer] = [:]
    private var prepared = false

    private init() {}

    func play(_ cue: SoundCue) {
        prepareIfNeeded()
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }

    private func prepareIfNeeded() {
        guard !prepared else { return }
        prepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for cue in SoundCue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav") else { continue }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[cue] = player
        }
    }
}
