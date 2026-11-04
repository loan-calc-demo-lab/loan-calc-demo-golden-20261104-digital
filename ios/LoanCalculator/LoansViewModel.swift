import Foundation
import Observation

/// State and actions behind LoansView: the signed-in customer's existing loans.
@Observable
final class LoansViewModel {
    private(set) var loans: [Loan] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    private let api: LoanAPI
    private let customerId: String

    init(api: LoanAPI = LoanAPI(), customerId: String = Session.customerId) {
        self.api = api
        self.customerId = customerId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            loans = try await api.customerLoans(customerId: customerId)
        } catch {
            loans = []
            errorMessage = "Your loans could not be loaded. Please try again."
        }
    }
}
