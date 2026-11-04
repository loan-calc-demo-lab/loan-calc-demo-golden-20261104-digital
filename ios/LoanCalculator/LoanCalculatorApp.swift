import SwiftUI

@main
struct LoanCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                LoansView()
                    .tabItem { Label("My loans", systemImage: "creditcard") }
                QuoteView()
                    .tabItem { Label("Loan quote", systemImage: "eurosign.circle") }
            }
        }
    }
}
