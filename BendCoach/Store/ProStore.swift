import Foundation
import StoreKit

/// The one-time "BendCoach Pro" unlock, using StoreKit 2.
@MainActor
final class ProStore: ObservableObject {
    static let proProductID = "com.astitvaswaroop.bendcoach.pro"

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
        debugUnlock = UserDefaults.standard.bool(forKey: PrefKey.debugPro)
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
        if let products = try? await Product.products(for: [Self.proProductID]) {
            product = products.first
        }
        await updateEntitlements()
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
