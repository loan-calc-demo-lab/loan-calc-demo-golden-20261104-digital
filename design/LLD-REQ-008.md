## Scope
- **AC1 (US1)** Given a loan that is in arrears, when the customer requests a top-up, then the system shows *Customer message TU-1a* "A top-up is not possible while a payment is overdue.".
- **AC2 (US1)** Given a loan with fewer than 6 payments made, when the customer requests a top-up, then the system shows *Customer message TU-1b* "A top-up is possible after your sixth monthly payment.".
- **AC3 (US1)** Given a loan without a repayment current account, when the customer requests a top-up, then the system shows *Customer message TU-1c* "We could not find your current account. Please contact us.".
- **AC4 (US1)** Given a loan that meets eligibility, when the customer requests a top-up, then the system proceeds to calculate the indicative offer.
- **AC5 (US2)** Given a top-up request of €5,000 for 60 months (reference R1), when eligibility is met, then the indicative offer displays:
  - top-up amount €5,000
  - term 60 months
  - new loan amount €13,940.27
  - rate 9.9 %
  - arrangement fee €50.00
  - amount paid out €4,950.00
  - monthly payment €295.50
  - APR 10.5 %
  - total cost of credit €3,840.05
  - total payable €17,780.32
  - label "Indicative offer – subject to final checks"
  as per **Top-up reference value R1**.
- **AC6 (US2)** Given a top-up request of €7,000 for 72 months (reference R2), when eligibility is met, then the indicative offer displays:
  - top-up amount €7,000
  - term 72 months
  - new loan amount €15,940.27
  - rate 8.9 %
  - arrangement fee €70.00
  - amount paid out €6,930.00
  - monthly payment €286.54
  - APR 9.4 %
  - total cost of credit €4,760.72
  - total payable €20,700.99
  as per **Top-up reference value R2**.
- **AC7 (US2)** Given a top-up request of €1,000 for 48 months (reference R3), when eligibility is met, then the indicative offer displays:
  - top-up amount €1,000
  - term 48 months
  - new loan amount €9,940.27
  - rate 9.9 %
  - arrangement fee €50.00
  - amount paid out €950.00
  - monthly payment €251.63
  - APR 10.7 %
  - total cost of credit €2,188.19
  - total payable €12,128.46
  as per **Top-up reference value R3**.
- **AC8 (US2)** Given a top-up amount outside €1,000-€20,000, when the customer enters the amount, then the system shows *Customer message TU-2a* "Please choose a top-up amount between €1,000 and €20,000.".
- **AC9 (US2)** Given a new loan amount that would exceed €30,000, when the calculation is performed, then the system shows *Customer message TU-2b* "The new loan amount can be at most €30,000.".
- **AC10 (US2)** Given a term outside 12-84 months, when the customer selects the term, then the system shows *Customer message TU-2c* "Please choose a term between 12 and 84 months.".
- **AC11 (US3)** Given an indicative offer has been shown, when 24 hours pass without acceptance, then the offer expires and the system shows *Customer message TU-4c* "This offer has expired. Please ask for a new offer.".
- **AC12 (US4)** Given the customer accepts a valid offer, when the acceptance is processed, then the system:
  - deducts the arrangement fee from the payout
  - credits the net amount to the repayment account (e.g., account balance after payout R1: €6,200.00)
  - creates a new loan with the combined amount and new monthly payment
  - shows a confirmation containing the amount paid in, the account, the new monthly payment, the first payment date and a 14-day withdrawal reminder (TU-5f)
  - stores the offer details as shown and the acceptance timestamp (REG-5).
- **AC13 (US5)** Given the customer attempts to accept the same offer a second time, when the second acceptance is received, then the system returns the result of the first acceptance and no additional payout occurs (TU-5e).

## Files
- ios/LoanCalculator/LoanAPI.swift – add methods `requestTopupOffer`, `acceptTopupOffer` and related models.
- ios/LoanCalculator/TopupOfferSummary.swift – view-model summary for the indicative offer.
- ios/LoanCalculator/TopupOfferView.swift – SwiftUI view showing the offer and accept button.
- ios/LoanCalculator/TopupOfferViewModel.swift – Observable view-model handling API calls, idempotency key storage and state.

## Types and functions
```swift
// MARK: - Request / Response models (snake_case on wire, camelCase in Swift)
struct TopupOfferRequest: Encodable {
    let customerId: String
    let topupAmount: Double
    let termMonths: Int
}

struct TopupOfferResponse: Decodable {
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
    let createdAt: Date
    let validUntil: Date
}

struct TopupAcceptResponse: Decodable {
    let offerId: String
    let loanId: String
    let status: String // "accepted"
    let acceptedAt: Date
    let amountPaidIn: Double
    let accountId: String
    let newMonthlyPayment: Double
    let firstPaymentDate: Date
    let payoutId: String
    let withdrawalReminder: String
}

extension LoanAPI {
    func requestTopupOffer(_ request: TopupOfferRequest) async throws -> TopupOfferResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("loans/\(request.customerId)/topup-offers"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        switch status {
        case 201:
            return try decoder.decode(TopupOfferResponse.self, from: data)
        case 404, 422, 503:
            throw LoanAPIError.rejected(status: status, message: "Server error \(status)")
        default:
            throw LoanAPIError.rejected(status: status, message: "Unexpected error")
        }
    }

    func acceptTopupOffer(offerId: String, idempotencyKey: String) async throws -> TopupAcceptResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("topup-offers/\(offerId)/accept"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        let (data, response) = try await session.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        switch status {
        case 200:
            return try decoder.decode(TopupAcceptResponse.self, from: data)
        case 404, 409, 410, 422, 503:
            throw LoanAPIError.rejected(status: status, message: "Server error \(status)")
        default:
            throw LoanAPIError.rejected(status: status, message: "Unexpected error")
        }
    }
}
```

## Behaviour
- **AC1-AC4**: `requestTopupOffer` is called after the user selects a loan. The view-model builds `TopupOfferRequest` from UI fields. On 422 the view-model surfaces the validation error with the field name.
- **AC5-AC10**: On 201 the response is mapped to `TopupOfferResponse`. The view-model stores `validUntil` and starts a local timer; if the timer expires before user accepts, UI shows the expiry message (TU-4c).
- **AC11-AC13**: When the user taps *Accept*, the view-model generates a UUID Idempotency-Key (persisted for the session) and calls `acceptTopupOffer`. A 200 response is shown; a repeat call with the same key returns the same `TopupAcceptResponse` and no second payout occurs (TU-5e). Errors are mapped to user-friendly messages as per AC12.

## Test plan
- `ios/LoanCalculatorTests/TopupOfferTests.swift`
  - `test_req008_ac1_in_arrears_shows_message`
  - `test_req008_ac2_fewer_than_6_payments_shows_message`
  - `test_req008_ac3_no_current_account_shows_message`
  - `test_req008_ac4_eligible_proceeds_to_offer`
  - `test_req008_ac5_indicator_offer_r1`
  - `test_req008_ac6_indicator_offer_r2`
  - `test_req008_ac7_indicator_offer_r3`
  - `test_req008_ac8_amount_out_of_range_shows_message`
  - `test_req008_ac9_new_loan_exceeds_limit_shows_message`
  - `test_req008_ac10_term_out_of_range_shows_message`
  - `test_req008_ac11_offer_expires_after_24h`
  - `test_req008_ac12_successful_acceptance_shows_confirmation`
  - `test_req008_ac13_idempotent_second_acceptance`

## Out of scope
- Android implementation.
- Full pre-contract document generation.
- Strong Customer Authentication flow.
- Credit decision engine integration.