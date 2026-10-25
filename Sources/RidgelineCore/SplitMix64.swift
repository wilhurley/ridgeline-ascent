/// Deterministic generator used for spawns, cairn offers, and daily runs.
/// Same seed and same call order produce the same stream on every platform.
public struct SplitMix64: Equatable {
    private var state: UInt64

    public init(seed: UInt64) {
        // A zero seed would still work, but shifting off zero keeps the first
        // values from collapsing toward a trivial sequence.
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<1`.
    public mutating func nextUnit() -> Double {
        let bits = next() >> 11
        return Double(bits) / Double(1 << 53)
    }

    /// Uniform integer in `0..<upperBound`.
    public mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}
