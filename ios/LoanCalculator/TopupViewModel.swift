import Foundation
import Observation

/// State and actions behind TopupView (REQ-008): choose amount and term, see the indicative offer, accept it.
@Observable
final class TopupViewModel {
    var amountText = "5000"
    var termText = "60"

    private(set) var offer: TopupOffer?
    private(set) var acceptResult: TopupResult?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    /// One key per offer: a retry after a lost answer reuses it, so the payout happens once (ARC-4, TU-5e).
    private(set) var idempotencyKey = UUID().uuidString

    private let api: LoanAPI

    init(api: LoanAPI = LoanAPI()) {
        self.api = api
    }

    var summaryRows: [QuoteRow] { offer.map(TopupSummary.rows(for:)) ?? [] }
    var confirmationRows: [QuoteRow] { acceptResult.map(TopupSummary.confirmationRows(for:)) ?? [] }

    /// AC1–AC4: ask Lending for an indicative offer. The app sends only the loan, amount and term (ARC-5).
    func loadOffer(loanId: String, amount: Double, term: Int) async {
        errorMessage = nil
        acceptResult = nil
        isLoading = true
        defer { isLoading = false }
        do {
            offer = try await api.requestTopupOffer(TopupOfferRequest(customerId: Session.customerId, topupAmount: amount,
                                                                       termMonths: term, loanId: loanId))
            idempotencyKey = UUID().uuidString
        } catch {
            offer = nil
            errorMessage = Self.message(for: error)
        }
    }

    /// Reads the amount and term fields, then loads the offer.
    func loadOffer(loanId: String) async {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: "")), let term = Int(termText) else {
            errorMessage = "Please enter an amount and a term."
            return
        }
        await loadOffer(loanId: loanId, amount: amount, term: term)
    }

    /// AC5–AC7: accept the offer; a repeat with the same key shows the same result.
    func acceptOffer(offerId: String, idempotencyKey key: String? = nil) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            acceptResult = try await api.acceptTopupOffer(offerId: offerId, idempotencyKey: key ?? idempotencyKey)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// The service's customer message (rulebook text) when it gives one.
    static func message(for error: Error) -> String {
        switch error {
        case LoanAPIError.rejected(_, let message), LoanAPIError.validation(_, let message):
            return message
        case LoanAPIError.unreachable:
            return "The service cannot be reached. Please try again."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
