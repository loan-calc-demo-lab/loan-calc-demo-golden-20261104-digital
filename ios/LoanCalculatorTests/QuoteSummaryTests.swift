import XCTest
@testable import LoanCalculator

/// What the quote screen shows, row by row (QuoteView renders QuoteSummary.rows).
@MainActor
final class QuoteSummaryTests: XCTestCase {
    private func quote() async throws -> Quote {
        let model = QuoteViewModel(api: LoanAPI(baseURL: URL(string: "http://loan.test")!, session: StubURLProtocol.session()))
        StubURLProtocol.handler = { _ in (200, Fixtures.quoteJSON) }
        await model.calculate()
        return try XCTUnwrap(model.quote)
    }

    func test_req001_monthlyPaymentIsTheFirstAndMostProminentRow() async throws {
        let rows = QuoteSummary.rows(for: try await quote())
        XCTAssertEqual(rows.first?.label, "Monthly payment")
        XCTAssertEqual(rows.first?.value, "€856.07")
        XCTAssertEqual(rows.first?.weight, .headline)
    }

    func test_req004_feeAndTotalPayableAreShown() async throws {
        let labels = QuoteSummary.rows(for: try await quote()).map(\.label)
        let fee = try XCTUnwrap(labels.firstIndex(of: "Arrangement fee"))
        let total = try XCTUnwrap(labels.firstIndex(of: "Total payable"))
        XCTAssertTrue(labels.contains("Total interest"))
        XCTAssertLessThan(fee, total)
    }
}
