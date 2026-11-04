import Foundation
import Observation

nonisolated struct FieldError: Equatable {
    /// API field name: principal, annual_rate_pct, term_months or upfront_fee.
    let field: String
    let message: String
}

/// State and actions behind QuoteView (REQ-001, REQ-003, REQ-004, REQ-005, REQ-006).
@Observable
final class QuoteViewModel {
    // Starting values, also restored by Reset (REQ-006).
    static let startPrincipal = "10000"
    static let startRate = "5"
    static let startTerm = "12"
    static let startFee = ""

    var principalText = QuoteViewModel.startPrincipal
    var rateText = QuoteViewModel.startRate
    var termText = QuoteViewModel.startTerm
    var feeText = QuoteViewModel.startFee

    private(set) var quote: Quote?
    private(set) var fieldError: FieldError?
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    private let api: LoanAPI

    init(api: LoanAPI = LoanAPI()) {
        self.api = api
    }

    /// REQ-006: true when the screen differs from its starting state.
    var canReset: Bool {
        quote != nil || fieldError != nil || errorMessage != nil
            || principalText != Self.startPrincipal || rateText != Self.startRate
            || termText != Self.startTerm || feeText != Self.startFee
    }

    /// REQ-006: back to the starting state: starting values, no quote, no messages.
    func reset() {
        principalText = Self.startPrincipal
        rateText = Self.startRate
        termText = Self.startTerm
        feeText = Self.startFee
        quote = nil
        fieldError = nil
        errorMessage = nil
    }

    func error(for field: String) -> String? {
        fieldError?.field == field ? fieldError?.message : nil
    }

    func calculate() async {
        errorMessage = nil
        fieldError = nil

        // REQ-003: catch obviously wrong input before calling the API; the API enforces the limits.
        guard let principal = Self.number(principalText) else { return fail("principal", "Enter the amount to borrow") }
        guard let rate = Self.number(rateText) else { return fail("annual_rate_pct", "Enter the interest rate") }
        guard let term = Int(termText.trimmingCharacters(in: .whitespaces)) else { return fail("term_months", "Enter the term in whole months") }
        // REQ-004: the fee is optional and defaults to 0.
        let feeInput = feeText.trimmingCharacters(in: .whitespaces)
        guard let fee = feeInput.isEmpty ? 0 : Self.number(feeInput) else { return fail("upfront_fee", "Enter the fee, or leave it empty") }

        isLoading = true
        defer { isLoading = false }
        do {
            quote = try await api.quote(QuoteRequest(principal: principal, annualRatePct: rate, termMonths: term, upfrontFee: fee))
        } catch LoanAPIError.validation(let field, let message) {
            fail(field, Self.sentence(message))
        } catch LoanAPIError.unreachable {
            quote = nil
            errorMessage = "Can't reach the loan service. Check your connection and try again."
        } catch {
            quote = nil
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func fail(_ field: String, _ message: String) {
        quote = nil
        fieldError = FieldError(field: field, message: message)
    }

    /// Accepts "10000", "10000.50" and "10000,50"; ignores spaces.
    static func number(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    private static func sentence(_ apiMessage: String) -> String {
        apiMessage.prefix(1).uppercased() + apiMessage.dropFirst()
    }
}
