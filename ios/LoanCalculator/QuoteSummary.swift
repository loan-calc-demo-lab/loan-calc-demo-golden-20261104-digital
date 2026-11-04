import Foundation

/// One row of the "Your quote" section.
nonisolated struct QuoteRow: Equatable, Identifiable {
    enum Weight: Equatable { case headline, body }

    /// Also the accessibility identifier of the row on screen.
    let id: String
    let label: String
    let explanation: String?
    let value: String
    let weight: Weight
}

/// The rows of the "Your quote" section, in display order. QuoteView renders exactly these rows, so their order,
/// labels, explanations and formatting can be tested without UI tests.
/// REQ-001 monthly payment, REQ-004 fee and total payable, REQ-007 APR and total cost of credit directly below
/// the monthly payment with the same visual weight. The repayment schedule screen receives only the schedule.
nonisolated enum QuoteSummary {
    static func rows(for quote: Quote) -> [QuoteRow] {
        [
            QuoteRow(id: "monthlyPayment", label: "Monthly payment", explanation: nil,
                     value: Money.eur(quote.monthlyPayment), weight: .headline),
            QuoteRow(id: "apr", label: "APR", explanation: "Annual percentage rate, including fees",
                     value: Percent.oneDecimal(quote.aprPct), weight: .headline),
            QuoteRow(id: "total_cost_of_credit", label: "Total cost of credit", explanation: nil,
                     value: Money.eur(quote.totalCostOfCredit), weight: .headline),
            QuoteRow(id: "totalInterest", label: "Total interest", explanation: nil,
                     value: Money.eur(quote.totalInterest), weight: .body),
            QuoteRow(id: "upfrontFee", label: "Arrangement fee", explanation: nil,
                     value: Money.eur(quote.upfrontFee), weight: .body),
            QuoteRow(id: "totalPayable", label: "Total payable", explanation: nil,
                     value: Money.eur(quote.totalPayable), weight: .body),
        ]
    }
}
