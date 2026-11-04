import XCTest
@testable import LoanCalculator

@MainActor
final class LoanAPITests: XCTestCase {
    private func makeAPI() -> LoanAPI {
        LoanAPI(baseURL: URL(string: "http://loan.test")!, session: StubURLProtocol.session())
    }

    func test_req001_decodesQuote() async throws {
        let api = makeAPI()
        StubURLProtocol.handler = { _ in (200, Fixtures.quoteJSON) }

        let quote = try await api.quote(QuoteRequest(principal: 10_000, annualRatePct: 5, termMonths: 12, upfrontFee: 250))

        XCTAssertEqual(quote.monthlyPayment, 856.07)
        XCTAssertEqual(quote.totalPayable, 10_522.84)
        XCTAssertEqual(quote.schedule.count, 2)
        XCTAssertEqual(quote.schedule[1].balance, 8_367.81)
    }

    func test_sendsSnakeCasePostToQuoteEndpoint() async throws {
        let api = makeAPI()
        StubURLProtocol.handler = { _ in (200, Fixtures.quoteJSON) }

        _ = try await api.quote(QuoteRequest(principal: 10_000, annualRatePct: 5, termMonths: 12, upfrontFee: 250))

        let sent = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(sent.request.httpMethod, "POST")
        XCTAssertEqual(sent.request.url?.absoluteString, "http://loan.test/loan/quote")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(json["principal"] as? Double, 10_000)
        XCTAssertEqual(json["annual_rate_pct"] as? Double, 5)
        XCTAssertEqual(json["term_months"] as? Int, 12)
        XCTAssertEqual(json["upfront_fee"] as? Double, 250)
    }

    func test_req003_mapsValidationError() async {
        let api = makeAPI()
        StubURLProtocol.handler = { _ in
            (422, #"{"error":"validation","field":"annual_rate_pct","message":"must be between 0 and 30"}"#)
        }

        do {
            _ = try await api.quote(QuoteRequest(principal: 10_000, annualRatePct: 45, termMonths: 12, upfrontFee: 0))
            XCTFail("expected a validation error")
        } catch {
            XCTAssertEqual(error as? LoanAPIError, .validation(field: "annual_rate_pct", message: "must be between 0 and 30"))
        }
    }

    func test_networkFailureIsReportedAsUnreachable() async {
        let api = makeAPI()
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        do {
            _ = try await api.quote(QuoteRequest(principal: 10_000, annualRatePct: 5, termMonths: 12, upfrontFee: 0))
            XCTFail("expected unreachable")
        } catch {
            XCTAssertEqual(error as? LoanAPIError, .unreachable)
        }
    }
}
