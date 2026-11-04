import XCTest
@testable import LoanCalculator

/// "My loans": the signed-in customer's existing loans, row by row (LoansView renders LoanSummary.rows).
@MainActor
final class LoansTests: XCTestCase {
    private func model() -> LoansViewModel {
        LoansViewModel(api: LoanAPI(baseURL: URL(string: "http://loan.test")!, session: StubURLProtocol.session()),
                       customerId: "CUST-1001")
    }

    func test_loansOfTheSignedInCustomerAreLoaded() async throws {
        let m = model()
        StubURLProtocol.handler = { _ in (200, Fixtures.loansJSON) }
        await m.load()
        XCTAssertEqual(StubURLProtocol.requests.first?.request.url?.path, "/customers/CUST-1001/loans")
        XCTAssertEqual(m.loans.map(\.loanId), ["PL-1001"])
        XCTAssertNil(m.errorMessage)
    }

    func test_outstandingBalanceIsTheHeadline() async throws {
        let m = model()
        StubURLProtocol.handler = { _ in (200, Fixtures.loansJSON) }
        await m.load()
        let rows = LoanSummary.rows(for: try XCTUnwrap(m.loans.first))
        XCTAssertEqual(rows.first?.label, "Outstanding balance")
        XCTAssertEqual(rows.first?.value, "€8,940.27")
        XCTAssertEqual(rows.first?.weight, .headline)
        XCTAssertEqual(rows.map(\.label), ["Outstanding balance", "Monthly payment", "Remaining term", "Interest rate"])
    }

    func test_serverErrorShowsAMessage() async {
        let m = model()
        StubURLProtocol.handler = { _ in (500, "{}") }
        await m.load()
        XCTAssertTrue(m.loans.isEmpty)
        XCTAssertEqual(m.errorMessage, "Your loans could not be loaded. Please try again.")
    }
}
