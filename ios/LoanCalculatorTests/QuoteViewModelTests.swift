import XCTest
@testable import LoanCalculator

@MainActor
final class QuoteViewModelTests: XCTestCase {
    private func makeModel() -> QuoteViewModel {
        QuoteViewModel(api: LoanAPI(baseURL: URL(string: "http://loan.test")!, session: StubURLProtocol.session()))
    }

    func test_req001_showsQuoteFromAPI() async {
        let model = makeModel()
        StubURLProtocol.handler = { _ in (200, Fixtures.quoteJSON) }

        await model.calculate()

        XCTAssertEqual(model.quote?.monthlyPayment, 856.07)
        XCTAssertNil(model.fieldError)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    func test_req003_nonNumericAmountIsRejectedWithoutCallingAPI() async {
        let model = makeModel()
        model.principalText = "ten thousand"

        await model.calculate()

        XCTAssertEqual(model.error(for: "principal"), "Enter the amount to borrow")
        XCTAssertNil(model.quote)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func test_req003_apiValidationErrorIsShownOnTheField() async {
        let model = makeModel()
        model.rateText = "45"
        StubURLProtocol.handler = { _ in
            (422, #"{"error":"validation","field":"annual_rate_pct","message":"must be between 0 and 30"}"#)
        }

        await model.calculate()

        XCTAssertEqual(model.error(for: "annual_rate_pct"), "Must be between 0 and 30")
        XCTAssertNil(model.error(for: "principal"))
        XCTAssertNil(model.quote)
    }

    func test_req004_emptyFeeIsSentAsZero() async throws {
        let model = makeModel()
        model.feeText = "  "
        StubURLProtocol.handler = { _ in (200, Fixtures.quoteJSON) }

        await model.calculate()

        let body = try XCTUnwrap(StubURLProtocol.requests.first?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["upfront_fee"] as? Double, 0)
    }

    func test_acceptsCommaAsDecimalSeparator() {
        XCTAssertEqual(QuoteViewModel.number("7,5"), 7.5)
        XCTAssertEqual(QuoteViewModel.number(" 10 000 "), 10_000)
        XCTAssertNil(QuoteViewModel.number(""))
        XCTAssertNil(QuoteViewModel.number("abc"))
    }

    func test_unreachableServiceShowsFriendlyMessage() async {
        let model = makeModel()
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }

        await model.calculate()

        XCTAssertEqual(model.errorMessage, "Can't reach the loan service. Check your connection and try again.")
        XCTAssertNil(model.quote)
    }

    func test_amountsAreShownInEuro() {
        XCTAssertEqual(Money.eur(856.07), "€856.07")
        XCTAssertEqual(Money.eur(10_522.84), "€10,522.84")
    }

    func test_req006_nothingToResetAtStart() {
        let model = makeModel()
        XCTAssertFalse(model.canReset)
        model.feeText = "250"
        XCTAssertTrue(model.canReset)
    }

    func test_req006_resetRestoresStartingValuesAndClearsQuote() async {
        let model = makeModel()
        model.principalText = "25000"
        model.rateText = "7,5"
        model.termText = "60"
        model.feeText = "250"
        StubURLProtocol.handler = { _ in (200, Fixtures.quoteJSON) }
        await model.calculate()
        XCTAssertNotNil(model.quote)

        model.reset()

        XCTAssertNil(model.quote)
        XCTAssertEqual(model.principalText, "10000")
        XCTAssertEqual(model.rateText, "5")
        XCTAssertEqual(model.termText, "12")
        XCTAssertEqual(model.feeText, "")
        XCTAssertFalse(model.canReset)
    }

    func test_req006_resetClearsErrorMessages() async {
        let model = makeModel()
        model.principalText = "abc"
        await model.calculate()
        XCTAssertNotNil(model.error(for: "principal"))

        model.reset()
        XCTAssertNil(model.fieldError)

        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        await model.calculate()
        XCTAssertNotNil(model.errorMessage)

        model.reset()
        XCTAssertNil(model.errorMessage)
    }
}
