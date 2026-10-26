/// Earned-only meta currency. Runs credit it. A future Base Camp spends it.
/// There is no path here that grants Embers from a purchase.
public final class EmbersWallet {
    public private(set) var balance: Int
    private let persist: (Int) -> Void

    public init(balance: Int = 0, persist: @escaping (Int) -> Void = { _ in }) {
        self.balance = max(0, balance)
        self.persist = persist
    }

    public func credit(_ amount: Int) {
        guard amount > 0 else { return }
        balance += amount
        persist(balance)
    }

    @discardableResult
    public func debit(_ amount: Int) -> Bool {
        guard amount > 0, balance >= amount else { return false }
        balance -= amount
        persist(balance)
        return true
    }
}
