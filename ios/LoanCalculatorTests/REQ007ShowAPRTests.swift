import XCTest
@testable import LoanCalculator

@MainActor
final class REQ007ShowAPRTests: XCTestCase {
    private func quote() async throws -> Quote {
        let model = QuoteViewModel(api: LoanAPI(baseURL: URL(string: "http://loan.test")!, session: StubURLProtocol.session()))
        StubURLProtocol.handler = { _ in (200, Fixtures.quoteJSON) }
        await model.calculate()
        return try XCTUnwrap(model.quote)
    }

    func test_req007_aprAndTotalCostDisplayed() async throws {
        let rows = QuoteSummary.rows(for: try await quote())
        // Find APR row
        let aprRow = try XCTUnwrap(rows.first { $0.id == "apr" })
        XCTAssertEqual(aprRow.label, "APR")
        XCTAssertEqual(aprRow.explanation, "Annual percentage rate, including fees")
        XCTAssertEqual(aprRow.value, "10.2%")
        XCTAssertEqual(aprRow.weight, .headline)
        // Find Total cost of credit row
        let costRow = try XCTUnwrap(rows.first { $0.id == "total_cost_of_credit" })
        XCTAssertEqual(costRow.label, "Total cost of credit")
        XCTAssertNil(costRow.explanation)
        XCTAssertEqual(costRow.value, "€522.89")
        XCTAssertEqual(costRow.weight, .headline)
    }
}
