## Scope
- AC1: Eligibility – loan not in arrears, at least 6 payments made, repayment from customer's current account (TU-1a, TU-1b, TU-1c).
- AC2: Eligibility – top-up amount within €1,000-€20,000 (TU-2a).
- AC3: Eligibility – resulting new loan amount ≤ €30,000 (TU-2b).
- AC4: Eligibility – term months 12-84 (TU-2c).
- AC5: Offer calculation – annual rate 9.9 % up to €15,000, 8.9 % above (TU-3a).
- AC6: Offer calculation – arrangement fee 1 % of top-up, min €50, max €300 (TU-3b).
- AC7: Offer calculation – amount paid out = top-up amount – arrangement fee (TU-4a).
- AC8: Offer fields order and label as per TU-4b.
- AC9: Offer validity 24 h (TU-4c).
- AC10: Acceptance – idempotent with Idempotency-Key, repeat returns same result, no double payout (TU-5e).
- AC11: Acceptance – returns payout_id, withdrawal_reminder (TU-5f).
- AC12: Error handling – 404 unknown offer, 409 Idempotency-Key conflict, 410 offer expired, 422 loan no longer eligible, 503 payout not confirmed (TU-5b-5e, REG-5).
- AC13: Logging & audit – store offer and acceptance details (REG-5).

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
        var urlRequest = URLRequest(url: baseURL.appending(path: "loans/\(request.customerId)/topup-offers"))
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
        case 404:
            throw LoanAPIError.server(status: 404)
        case 422:
            let body = try? decoder.decode(ValidationBody.self, from: data)
            throw LoanAPIError.validation(field: body?.field ?? "", message: body?.message ?? "Invalid input")
        default:
            throw LoanAPIError.server(status: status)
        }
    }

    func acceptTopupOffer(offerId: String, idempotencyKey: String) async throws -> TopupAcceptResponse {
        var urlRequest = URLRequest(url: baseURL.appending(path: "topup-offers/\(offerId)/accept"))
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
            throw LoanAPIError.server(status: status)
        default:
            throw LoanAPIError.server(status: status)
        }
    }
}
```

## Behaviour
- **AC1-AC4**: `requestTopupOffer` is called after the user selects a loan. The client builds `TopupOfferRequest` from UI fields. The API validates eligibility; on 422 the view-model surfaces the `validation` error with field name.
- **AC5-AC9**: On 201 the response is mapped to `TopupOfferResponse`. The view-model stores `validUntil` and starts a local timer; if the timer expires before user accepts, UI shows the expiry message (TU-4c).
- **AC10-AC11**: When the user taps *Accept*, the view-model generates a UUID Idempotency-Key (persisted for the session) and calls `acceptTopupOffer`. A 200 response is shown; a repeat call with the same key returns the same `TopupAcceptResponse` and no second payout occurs (TU-5e). The view displays `withdrawalReminder`.
- **AC12**: Errors are mapped to user-friendly messages:
  - 404 → "Offer not found. Please request a new offer."
  - 409 → "This action was already performed with a different offer."
  - 410 → "The offer has expired. Request a new one."
  - 422 → validation message from server.
  - 503 → "Payout not confirmed, please try again later."
- **AC13**: On successful acceptance the view-model calls a logging service (provided by the app core) to store the offer and acceptance timestamps (REG-5).

## Test plan
- `ios/LoanCalculatorTests/TopupOfferTests.swift`
  - `testRequestTopupOffer_success` – mock URLSession returns 201 with full response, verify view-model state.
  - `testRequestTopupOffer_eligibilityError` – mock 422, verify validation error propagated.
  - `testAcceptTopupOffer_idempotent` – first call returns 200, second call with same key returns same object, no additional network call.
  - `testAcceptTopupOffer_expired` – mock 410, verify UI shows expiry message.
  - `testAcceptTopupOffer_payoutNotConfirmed` – mock 503, verify retry hint.

## Out of scope
- Android implementation (future release).
- Full pre-contract document generation (REG-1 out of scope).
- Strong Customer Authentication flow (REG-4 out of scope).
- Credit decision engine integration (REG-2 out of scope).
