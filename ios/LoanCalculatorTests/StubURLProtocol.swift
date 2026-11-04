import Foundation

/// Answers URLSession requests in tests without a server.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (status: Int, body: String))?
    nonisolated(unsafe) static var requests: [(request: URLRequest, body: Data)] = []

    static func session() -> URLSession {
        handler = nil
        requests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        // URLSession moves httpBody into a stream before it reaches a URLProtocol.
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll) ?? Data()
        Self.requests.append((request, body))
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (status, text) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(text.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

enum Fixtures {
    /// Shape of a real /loan/quote answer, shortened to two months.
    static let quoteJSON = """
    {"monthly_payment":856.07,"total_interest":272.84,"upfront_fee":250.0,"total_payable":10522.84,
     "total_cost_of_credit":522.89,"apr_pct":10.2,
     "schedule":[{"month":1,"payment":856.07,"principal":814.4,"interest":41.67,"balance":9185.6},
                 {"month":2,"payment":856.07,"principal":817.79,"interest":38.28,"balance":8367.81}]}
    """

    /// Shape of a real /customers/CUST-1001/loans answer (demo customer).
    static let loansJSON = """
    {"customer_id":"CUST-1001","loans":[{"loan_id":"PL-1001","customer_id":"CUST-1001","product":"Personal loan",
     "original_principal":12000.0,"annual_rate_pct":8.9,"term_months":60,"payments_made":18,"remaining_term_months":42,
     "outstanding_balance":8940.27,"monthly_payment":248.52,"in_arrears":false,"repayment_account_id":"CA-2001"}]}
    """
}
