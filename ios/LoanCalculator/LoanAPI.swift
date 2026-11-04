import Foundation

// Client for the Lending loan service: POST /loan/quote (REQ-001..REQ-005, REQ-007) and
// GET /customers/{id}/loans (the customer's existing loans).
// JSON uses snake_case on the wire; Swift uses camelCase.

nonisolated struct QuoteRequest: Encodable, Equatable {
    var principal: Double
    var annualRatePct: Double
    var termMonths: Int
    var upfrontFee: Double
}

nonisolated struct ScheduleRow: Decodable, Equatable, Identifiable {
    let month: Int
    let payment: Double
    let principal: Double
    let interest: Double
    let balance: Double

    var id: Int { month }
}

nonisolated struct Quote: Decodable, Equatable {
    let monthlyPayment: Double
    let totalInterest: Double
    let upfrontFee: Double
    let totalPayable: Double
    /// REQ-007: interest plus the arrangement fee, in EUR.
    let totalCostOfCredit: Double
    /// REQ-007: annual percentage rate in percent, one decimal place.
    let aprPct: Double
    let schedule: [ScheduleRow]
}

/// An existing loan of the signed-in customer.
nonisolated struct Loan: Decodable, Equatable, Identifiable {
    let loanId: String
    let customerId: String
    let product: String
    let originalPrincipal: Double
    let annualRatePct: Double
    let termMonths: Int
    let paymentsMade: Int
    let remainingTermMonths: Int
    let outstandingBalance: Double
    let monthlyPayment: Double
    let inArrears: Bool
    let repaymentAccountId: String

    var id: String { loanId }
}

nonisolated struct CustomerLoans: Decodable, Equatable {
    let customerId: String
    let loans: [Loan]
}

nonisolated enum LoanAPIError: Error, Equatable {
    /// REQ-003: the API rejected an input; `field` is the API field name.
    case validation(field: String, message: String)
    case server(status: Int)
    case unreachable
}

final class LoanAPI {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = LoanAPI.configuredBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// From Info.plist key `LoanAPIBaseURL` (build setting LOAN_API_BASE_URL).
    static var configuredBaseURL: URL {
        if let text = Bundle.main.object(forInfoDictionaryKey: "LoanAPIBaseURL") as? String,
           let url = URL(string: text), url.scheme != nil {
            return url
        }
        return URL(string: "http://localhost:8080")!
    }

    func quote(_ request: QuoteRequest) async throws -> Quote {
        var urlRequest = URLRequest(url: baseURL.appending(path: "loan/quote"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30  // allows for a cold start of the API on IBM Code Engine (scale to zero)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw LoanAPIError.unreachable
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            return try decoder.decode(Quote.self, from: data)
        case 422:
            let body = try? decoder.decode(ValidationBody.self, from: data)
            throw LoanAPIError.validation(field: body?.field ?? "", message: body?.message ?? "Invalid input")
        default:
            throw LoanAPIError.server(status: status)
        }
    }

    /// The customer's existing loans.
    func customerLoans(customerId: String) async throws -> [Loan] {
        var urlRequest = URLRequest(url: baseURL.appending(path: "customers/\(customerId)/loans"))
        urlRequest.timeoutInterval = 30  // allows for a cold start of the API on IBM Code Engine (scale to zero)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw LoanAPIError.unreachable
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw LoanAPIError.server(status: status) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CustomerLoans.self, from: data).loans
    }

    private nonisolated struct ValidationBody: Decodable {
        let field: String
        let message: String
    }
}
