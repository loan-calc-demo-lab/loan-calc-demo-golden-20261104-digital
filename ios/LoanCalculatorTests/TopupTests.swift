// REQ-008: Loan top-up tests
import XCTest
@testable import LoanCalculator

@MainActor
final class TopupTests: XCTestCase {
    var api: LoanAPI!
    var session: URLSession!
    /// The stub of the current test. Called by StubURLProtocol on its own thread, so it is kept in a
    /// nonisolated static (like StubURLProtocol.handler) and never hops to the main actor.
    nonisolated(unsafe) static var stub: (URLRequest) -> (Int, [String: Any]) = { _ in (500, [:]) }
    var handler: (URLRequest) -> (Int, [String: Any]) {
        get { Self.stub }
        set { Self.stub = newValue }
    }

    override func setUp() async throws {
        try await super.setUp()
        session = StubURLProtocol.session()
        api = LoanAPI(baseURL: URL(string: "http://loan.test")!, session: session)
        StubURLProtocol.handler = { request in
            let (status, object) = TopupTests.stub(request)
            let data = try JSONSerialization.data(withJSONObject: object)
            return (status, String(decoding: data, as: UTF8.self))
        }
    }

    // AC1: loan in arrears
    func test_req008_ac1_topup_not_possible_while_overdue() async throws {
        handler = { request in
            XCTAssertEqual(request.url?.path, "/loans/PL-1002/topup-offers")
            return (422, ["message": "A top-up is not possible while a payment is overdue."])
        }
        let req = TopupOfferRequest(customerId: "CUST-1002", topupAmount: 5000, termMonths: 60, loanId: "PL-1002")
        do {
            _ = try await api.requestTopupOffer(req)
            XCTFail("Expected rejection")
        } catch let error as LoanAPIError {
            switch error {
            case .rejected(let status, let message):
                XCTAssertEqual(status, 422)
                XCTAssertEqual(message, "A top-up is not possible while a payment is overdue.")
            default:
                XCTFail("Unexpected error")
            }
        }
    }

    // AC2: fewer than 6 payments
    func test_req008_ac2_topup_possible_after_six_payments() async throws {
        handler = { request in
            XCTAssertEqual(request.url?.path, "/loans/PL-1003/topup-offers")
            return (422, ["message": "A top-up is possible after your sixth monthly payment."])
        }
        let req = TopupOfferRequest(customerId: "CUST-1003", topupAmount: 5000, termMonths: 60, loanId: "PL-1003")
        do {
            _ = try await api.requestTopupOffer(req)
            XCTFail("Expected rejection")
        } catch let error as LoanAPIError {
            if case .rejected(let status, let message) = error {
                XCTAssertEqual(status, 422)
                XCTAssertEqual(message, "A top-up is possible after your sixth monthly payment.")
            } else { XCTFail("Unexpected error") }
        }
    }

    // AC3: no repayment account
    func test_req008_ac3_no_current_account() async throws {
        handler = { request in
            XCTAssertEqual(request.url?.path, "/loans/PL-1004/topup-offers")
            return (422, ["message": "We could not find your current account. Please contact us."])
        }
        let req = TopupOfferRequest(customerId: "CUST-1004", topupAmount: 5000, termMonths: 60, loanId: "PL-1004")
        do {
            _ = try await api.requestTopupOffer(req)
            XCTFail("Expected rejection")
        } catch let error as LoanAPIError {
            if case .rejected(let status, let message) = error {
                XCTAssertEqual(status, 422)
                XCTAssertEqual(message, "We could not find your current account. Please contact us.")
            } else { XCTFail("Unexpected error") }
        }
    }

    // AC5: indicative offer R1
    func test_req008_ac5_indicative_offer_r1() async throws {
        handler = { request in
            XCTAssertEqual(request.url?.path, "/loans/PL-1001/topup-offers")
            let json: [String: Any] = [
                "offer_id": "off-1",
                "loan_id": "PL-1001",
                "customer_id": "CUST-1001",
                "indicative": true,
                "label": "Indicative offer – subject to final checks",
                "topup_amount": 5000.0,
                "term_months": 60,
                "new_loan_amount": 13940.27,
                "annual_rate_pct": 9.9,
                "arrangement_fee": 50.0,
                "amount_paid_out": 4950.0,
                "monthly_payment": 295.50,
                "apr_pct": 10.5,
                "total_cost_of_credit": 3840.05,
                "total_payable": 17780.32,
                "created_at": "2026-11-04T10:00:00Z",
                "valid_until": "2026-11-05T10:00:00Z"
            ]
            return (201, json)
        }
        let req = TopupOfferRequest(customerId: "CUST-1001", topupAmount: 5000, termMonths: 60, loanId: "PL-1001")
        let resp = try await api.requestTopupOffer(req)
        XCTAssertEqual(resp.offerId, "off-1")
        XCTAssertEqual(resp.topupAmount, 5000.0)
        XCTAssertEqual(resp.termMonths, 60)
        XCTAssertEqual(resp.newLoanAmount, 13940.27)
        XCTAssertEqual(resp.annualRatePct, 9.9)
        XCTAssertEqual(resp.arrangementFee, 50.0)
        XCTAssertEqual(resp.amountPaidOut, 4950.0)
        XCTAssertEqual(resp.monthlyPayment, 295.50)
        XCTAssertEqual(resp.aprPct, 10.5)
        XCTAssertEqual(resp.totalCostOfCredit, 3840.05)
        XCTAssertEqual(resp.totalPayable, 17780.32)
        XCTAssertEqual(resp.label, "Indicative offer – subject to final checks")
    }

    // AC6: indicative offer R2
    func test_req008_ac6_indicative_offer_r2() async throws {
        handler = { request in
            let json: [String: Any] = [
                "offer_id": "off-2",
                "loan_id": "PL-1001",
                "customer_id": "CUST-1001",
                "indicative": true,
                "label": "Indicative offer – subject to final checks",
                "topup_amount": 7000.0,
                "term_months": 72,
                "new_loan_amount": 15940.27,
                "annual_rate_pct": 8.9,
                "arrangement_fee": 70.0,
                "amount_paid_out": 6930.0,
                "monthly_payment": 286.54,
                "apr_pct": 9.4,
                "total_cost_of_credit": 4760.72,
                "total_payable": 20700.99,
                "created_at": "2026-11-04T10:00:00Z",
                "valid_until": "2026-11-05T10:00:00Z"
            ]
            return (201, json)
        }
        let req = TopupOfferRequest(customerId: "CUST-1001", topupAmount: 7000, termMonths: 72, loanId: "PL-1001")
        let resp = try await api.requestTopupOffer(req)
        XCTAssertEqual(resp.offerId, "off-2")
        XCTAssertEqual(resp.topupAmount, 7000.0)
        XCTAssertEqual(resp.termMonths, 72)
        XCTAssertEqual(resp.newLoanAmount, 15940.27)
        XCTAssertEqual(resp.annualRatePct, 8.9)
        XCTAssertEqual(resp.arrangementFee, 70.0)
        XCTAssertEqual(resp.amountPaidOut, 6930.0)
        XCTAssertEqual(resp.monthlyPayment, 286.54)
        XCTAssertEqual(resp.aprPct, 9.4)
        XCTAssertEqual(resp.totalCostOfCredit, 4760.72)
        XCTAssertEqual(resp.totalPayable, 20700.99)
    }

    // AC7: indicative offer R3
    func test_req008_ac7_indicative_offer_r3() async throws {
        handler = { request in
            let json: [String: Any] = [
                "offer_id": "off-3",
                "loan_id": "PL-1001",
                "customer_id": "CUST-1001",
                "indicative": true,
                "label": "Indicative offer – subject to final checks",
                "topup_amount": 1000.0,
                "term_months": 48,
                "new_loan_amount": 9940.27,
                "annual_rate_pct": 9.9,
                "arrangement_fee": 50.0,
                "amount_paid_out": 950.0,
                "monthly_payment": 251.63,
                "apr_pct": 10.7,
                "total_cost_of_credit": 2188.19,
                "total_payable": 12128.46,
                "created_at": "2026-11-04T10:00:00Z",
                "valid_until": "2026-11-05T10:00:00Z"
            ]
            return (201, json)
        }
        let req = TopupOfferRequest(customerId: "CUST-1001", topupAmount: 1000, termMonths: 48, loanId: "PL-1001")
        let resp = try await api.requestTopupOffer(req)
        XCTAssertEqual(resp.offerId, "off-3")
        XCTAssertEqual(resp.topupAmount, 1000.0)
        XCTAssertEqual(resp.termMonths, 48)
        XCTAssertEqual(resp.newLoanAmount, 9940.27)
        XCTAssertEqual(resp.annualRatePct, 9.9)
        XCTAssertEqual(resp.arrangementFee, 50.0)
        XCTAssertEqual(resp.amountPaidOut, 950.0)
        XCTAssertEqual(resp.monthlyPayment, 251.63)
        XCTAssertEqual(resp.aprPct, 10.7)
        XCTAssertEqual(resp.totalCostOfCredit, 2188.19)
        XCTAssertEqual(resp.totalPayable, 12128.46)
    }

    // AC8: amount out of range
    func test_req008_ac8_amount_out_of_range() async throws {
        handler = { request in
            return (422, ["message": "Please choose a top-up amount between €1,000 and €20,000."])
        }
        let req = TopupOfferRequest(customerId: "CUST-1001", topupAmount: 999, termMonths: 60, loanId: "PL-1001")
        do {
            _ = try await api.requestTopupOffer(req)
            XCTFail("Expected rejection")
        } catch let error as LoanAPIError {
            if case .rejected(let status, let message) = error {
                XCTAssertEqual(status, 422)
                XCTAssertEqual(message, "Please choose a top-up amount between €1,000 and €20,000.")
            }
        }
    }

    // AC9: new loan amount exceeds limit
    func test_req008_ac9_new_loan_too_large() async throws {
        handler = { request in
            return (422, ["message": "The new loan amount can be at most €30,000."])
        }
        let req = TopupOfferRequest(customerId: "CUST-1001", topupAmount: 20000, termMonths: 84, loanId: "PL-1001")
        do {
            _ = try await api.requestTopupOffer(req)
            XCTFail("Expected rejection")
        } catch let error as LoanAPIError {
            if case .rejected(let status, let message) = error {
                XCTAssertEqual(status, 422)
                XCTAssertEqual(message, "The new loan amount can be at most €30,000.")
            }
        }
    }

    // AC10: term out of range
    func test_req008_ac10_term_out_of_range() async throws {
        handler = { request in
            return (422, ["message": "Please choose a term between 12 and 84 months."])
        }
        let req = TopupOfferRequest(customerId: "CUST-1001", topupAmount: 5000, termMonths: 11, loanId: "PL-1001")
        do {
            _ = try await api.requestTopupOffer(req)
            XCTFail("Expected rejection")
        } catch let error as LoanAPIError {
            if case .rejected(let status, let message) = error {
                XCTAssertEqual(status, 422)
                XCTAssertEqual(message, "Please choose a term between 12 and 84 months.")
            }
        }
    }

    // AC11: offer expires after 24h
    func test_req008_ac11_offer_expires() async throws {
        // first request returns offer
        handler = { request in
            let json: [String: Any] = [
                "offer_id": "off-1",
                "loan_id": "PL-1001",
                "customer_id": "CUST-1001",
                "indicative": true,
                "label": "Indicative offer – subject to final checks",
                "topup_amount": 5000.0,
                "term_months": 60,
                "new_loan_amount": 13940.27,
                "annual_rate_pct": 9.9,
                "arrangement_fee": 50.0,
                "amount_paid_out": 4950.0,
                "monthly_payment": 295.50,
                "apr_pct": 10.5,
                "total_cost_of_credit": 3840.05,
                "total_payable": 17780.32,
                "created_at": "2026-11-04T10:00:00Z",
                "valid_until": "2026-11-05T10:00:00Z"
            ]
            return (201, json)
        }
        let req = TopupOfferRequest(customerId: "CUST-1001", topupAmount: 5000, termMonths: 60, loanId: "PL-1001")
        let _ = try await api.requestTopupOffer(req)
        // simulate time after 24h+1s by calling accept and expecting expiry error
        handler = { request in
            return (410, ["message": "This offer has expired. Please ask for a new offer."])
        }
        do {
            _ = try await api.acceptTopupOffer(offerId: "off-1", idempotencyKey: "k1")
            XCTFail("Expected expiry rejection")
        } catch let error as LoanAPIError {
            if case .rejected(let status, let message) = error {
                XCTAssertEqual(status, 410)
                XCTAssertEqual(message, "This offer has expired. Please ask for a new offer.")
            }
        }
    }

    // AC12: successful acceptance
    func test_req008_ac12_accept_success() async throws {
        // stub accept response
        handler = { request in
            let json: [String: Any] = [
                "offer_id": "off-1",
                "loan_id": "PL-1001",
                "status": "accepted",
                "accepted_at": "2026-11-04T12:00:00Z",
                "amount_paid_in": 4950.0,
                "account_id": "CA-2001",
                "new_monthly_payment": 295.50,
                "first_payment_date": "2026-12-01",
                "payout_id": "pout-1",
                "withdrawal_reminder": "You can withdraw within 14 days."
            ]
            return (200, json)
        }
        let resp = try await api.acceptTopupOffer(offerId: "off-1", idempotencyKey: "k1")
        XCTAssertEqual(resp.offerId, "off-1")
        XCTAssertEqual(resp.amountPaidIn, 4950.0)
        XCTAssertEqual(resp.accountId, "CA-2001")
        XCTAssertEqual(resp.newMonthlyPayment, 295.50)
        XCTAssertEqual(resp.withdrawalReminder, "You can withdraw within 14 days.")
    }

    // AC13: repeat acceptance idempotent
    func test_req008_ac13_repeat_acceptance() async throws {
        // first accept
        var callCount = 0
        handler = { request in
            callCount += 1
            let json: [String: Any] = [
                "offer_id": "off-1",
                "loan_id": "PL-1001",
                "status": "accepted",
                "accepted_at": "2026-11-04T12:00:00Z",
                "amount_paid_in": 4950.0,
                "account_id": "CA-2001",
                "new_monthly_payment": 295.50,
                "first_payment_date": "2026-12-01",
                "payout_id": "pout-1",
                "withdrawal_reminder": "You can withdraw within 14 days."
            ]
            return (200, json)
        }
        let _ = try await api.acceptTopupOffer(offerId: "off-1", idempotencyKey: "k1")
        // second accept with same idempotency key
        let resp2 = try await api.acceptTopupOffer(offerId: "off-1", idempotencyKey: "k1")
        XCTAssertEqual(resp2.offerId, "off-1")
        XCTAssertEqual(callCount, 2) // server returns same result, no extra payout
    }
}
