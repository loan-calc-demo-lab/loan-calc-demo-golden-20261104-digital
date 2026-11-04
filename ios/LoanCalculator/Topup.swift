import Foundation

// REQ-008: loan top-up, client side of the contract lending-topup-v1 (snake_case on the wire, camelCase here).

/// TU-4b: the indicative offer as the Lending service returns it.
nonisolated struct TopupOffer: Decodable, Equatable {
    let offerId: String
    let loanId: String
    let customerId: String
    let indicative: Bool
    let label: String
    let topupAmount: Double
    let termMonths: Int
    let newLoanAmount: Double
    let annualRatePct: Double
    let arrangementFee: Double
    let amountPaidOut: Double
    let monthlyPayment: Double
    let aprPct: Double
    let totalCostOfCredit: Double
    let totalPayable: Double
    let createdAt: String
    let validUntil: String
}

/// TU-5f: the result of accepting an offer.
nonisolated struct TopupResult: Decodable, Equatable {
    let offerId: String
    let loanId: String
    let status: String
    let acceptedAt: String
    let amountPaidIn: Double
    let accountId: String
    let newMonthlyPayment: Double
    let firstPaymentDate: String
    let payoutId: String
    let withdrawalReminder: String
}

nonisolated struct TopupOfferRequest: Encodable, Equatable {
    let customerId: String
    let topupAmount: Double
    let termMonths: Int
    /// The loan to top up; goes into the path, not the body (contract lending-topup-v1).
    var loanId: String = ""

    private enum CodingKeys: String, CodingKey { case customerId, topupAmount, termMonths }
}

nonisolated struct TopupAcceptRequest: Encodable, Equatable {
    let customerId: String
}
