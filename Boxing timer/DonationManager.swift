//
//  DonationManager.swift
//  Boxing timer
//
//  Verwaltet In-App Käufe für den Tip Jar (Donation).
//  Produkt-IDs müssen in App Store Connect identisch angelegt werden.
//

import StoreKit
import Foundation
import SwiftUI

// MARK: - Donation Manager
@MainActor
class DonationManager: ObservableObject {

    static let shared = DonationManager()

    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseSuccess = false
    @Published var errorMessage: String?

    // ⚠️ Diese IDs müssen in App Store Connect unter "In-App Purchases"
    // exakt so erstellt werden (Typ: Consumable)
    private let productIDs: Set<String> = [
        "tip.coffee",    // 0,99 €  – Kleiner Kaffee
        "tip.training",  // 2,99 €  – Training sponsern
        "tip.champion"   // 10,99 € – Großes Dankeschön
    ]

    // Produkte vom App Store laden
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: productIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Kauf auslösen
    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    purchaseSuccess = true
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
}
