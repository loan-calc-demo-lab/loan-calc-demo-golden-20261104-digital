import Foundation

/// REQ-008: what the top-up screens show, row by row (rulebook "offer screen labels and values", TU-4b, TU-5f).
/// TopupView renders exactly these rows, so the screen content is tested without UI tests.
nonisolated enum TopupSummary {
    /// The indicative offer, in the order of TU-4b.
    static func rows(for offer: TopupOffer) -> [QuoteRow] {
        [
            QuoteRow(id: "monthlyPayment", label: "Monthly payment", explanation: nil,
                     value: Money.eur(offer.monthlyPayment), weight: .headline),
            QuoteRow(id: "aprPct", label: "APR", explanation: "Annual percentage rate, including fees",
                     value: Percent.oneDecimal(offer.aprPct), weight: .headline),
            QuoteRow(id: "totalCostOfCredit", label: "Total cost of credit", explanation: nil,
                     value: Money.eur(offer.totalCostOfCredit), weight: .headline),
            QuoteRow(id: "topupAmount", label: "Top-up amount", explanation: nil, value: Money.eur(offer.topupAmount), weight: .body),
            QuoteRow(id: "arrangementFee", label: "Arrangement fee", explanation: nil, value: Money.eur(offer.arrangementFee), weight: .body),
            QuoteRow(id: "amountPaidOut", label: "Paid into your account", explanation: nil, value: Money.eur(offer.amountPaidOut), weight: .body),
            QuoteRow(id: "newLoanAmount", label: "New loan amount", explanation: nil, value: Money.eur(offer.newLoanAmount), weight: .body),
            QuoteRow(id: "termMonths", label: "Term", explanation: nil, value: "\(offer.termMonths) months", weight: .body),
            QuoteRow(id: "annualRatePct", label: "Interest rate", explanation: nil, value: Percent.oneDecimal(offer.annualRatePct), weight: .body),
            QuoteRow(id: "totalPayable", label: "Total amount payable", explanation: nil, value: Money.eur(offer.totalPayable), weight: .body),
            QuoteRow(id: "validUntil", label: "Valid until", explanation: nil, value: Self.dateTime(offer.validUntil), weight: .body),
        ]
    }

    /// The confirmation after acceptance (TU-5f); the withdrawal reminder is shown below the rows.
    static func confirmationRows(for result: TopupResult) -> [QuoteRow] {
        [
            QuoteRow(id: "amountPaidIn", label: "Paid into your account", explanation: nil, value: Money.eur(result.amountPaidIn), weight: .headline),
            QuoteRow(id: "accountId", label: "Account", explanation: nil, value: result.accountId, weight: .body),
            QuoteRow(id: "newMonthlyPayment", label: "New monthly payment", explanation: nil, value: Money.eur(result.newMonthlyPayment), weight: .body),
            QuoteRow(id: "firstPaymentDate", label: "First payment", explanation: nil, value: result.firstPaymentDate, weight: .body),
        ]
    }

    /// "2026-11-05T15:44:49Z" -> "2026-11-05 15:44 UTC".
    static func dateTime(_ iso: String) -> String {
        guard iso.count >= 16 else { return iso }
        let chars = Array(iso)
        return String(chars[0..<10]) + " " + String(chars[11..<16]) + " UTC"
    }
}
