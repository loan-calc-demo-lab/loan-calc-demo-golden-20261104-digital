import Foundation

/// The rows shown for one existing loan on the "My loans" screen, in display order. LoansView renders exactly these
/// rows (same pattern as QuoteSummary), so the screen content can be tested without UI tests.
nonisolated enum LoanSummary {
    static func rows(for loan: Loan) -> [QuoteRow] {
        [
            QuoteRow(id: "outstandingBalance", label: "Outstanding balance", explanation: nil,
                     value: Money.eur(loan.outstandingBalance), weight: .headline),
            QuoteRow(id: "monthlyPayment", label: "Monthly payment", explanation: nil,
                     value: Money.eur(loan.monthlyPayment), weight: .body),
            QuoteRow(id: "remainingTermMonths", label: "Remaining term", explanation: nil,
                     value: "\(loan.remainingTermMonths) months", weight: .body),
            QuoteRow(id: "annualRatePct", label: "Interest rate", explanation: nil,
                     value: Percent.oneDecimal(loan.annualRatePct), weight: .body),
        ]
    }
}
