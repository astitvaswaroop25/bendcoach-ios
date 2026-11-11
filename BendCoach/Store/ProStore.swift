import Foundation
import StoreKit

/// The one-time "BendCoach Pro" unlock, using StoreKit 2.
@MainActor
final class ProStore: ObservableObject {
    static let proProductID = "com.astitvaswaroop.bendcoach.pro"

    enum Status: Equatable {
        case loading
        case ready
        /// No product came back: offline, or a build the App Store doesn't know about
        /// (sideloaded or run outside Xcode's StoreKit testing).
        case unavailable
    }

    /// True in builds that offer a test unlock instead of a purchase.
    static var offersTestUnlock: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    @Published private(set) var status: Status = .loading
    @Published private(set) var product: Product?
    @Published private(set) var hasPurchasedPro = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?
    /// Lets debug builds test Pro screens without a purchase. Always off in release builds.
    @Published var debugUnlock: Bool {
        didSet { UserDefaults.standard.set(debugUnlock, forKey: PrefKey.debugPro) }
    }

    private var updatesTask: Task<Void, Never>?

    var isPro: Bool { hasPurchasedPro || debugUnlock }

    init() {
        #if DEBUG
        debugUnlock = UserDefaults.standard.bool(forKey: PrefKey.debugPro) || Demo.unlocksPro
        #else
        debugUnlock = false
        #endif

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { [weak self] in
            await self?.refresh()
        }
    }

    func refresh() async {
        status = .loading
        if let loaded = await loadProduct(timeout: .seconds(12)) {
            product = loaded
        }
        status = product == nil ? .unavailable : .ready
        await updateEntitlements()
    }

    /// Asks the App Store for the Pro product, giving up after `timeout` so the paywall never
    /// spins forever. A product that arrives after the timeout still turns the paywall ready.
    private func loadProduct(timeout: Duration) async -> Product? {
        await withCheckedContinuation { continuation in
            let first = FirstResult(continuation)
            Task { @MainActor [weak self] in
                let loaded = (try? await Product.products(for: [Self.proProductID]))?.first
                if let loaded, let self, self.product == nil {
                    self.product = loaded
                    self.status = .ready
                }
                first.resume(loaded)
            }
            Task {
                try? await Task.sleep(for: timeout)
                first.resume(nil)
            }
        }
    }

    func updateEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        hasPurchasedPro = owned
    }

    func purchase() async {
        guard let product else {
            errorMessage = "The App Store isn't reachable right now. Try again in a minute."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateEntitlements()
                case .unverified:
                    errorMessage = "The App Store couldn't verify this purchase."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await updateEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result {
            await transaction.finish()
        }
        await updateEntitlements()
    }
}

/// Resumes a continuation with whichever result comes first and ignores the rest.
private final class FirstResult<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Value) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
