import SwiftUI

/// "My loans": the signed-in customer's existing personal loans.
struct LoansView: View {
    @State private var model = LoansViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let message = model.errorMessage {
                    Text(message).foregroundStyle(.red).accessibilityIdentifier("loansError")
                }
                ForEach(model.loans) { loan in
                    Section("\(loan.product) \(loan.loanId)") {
                        ForEach(LoanSummary.rows(for: loan)) { row in
                            LabeledContent(row.label, value: row.value)
                                .font(row.weight == .headline ? .headline : .body)
                                .accessibilityIdentifier(row.id)
                        }
                        // REQ-008: top up this loan.
                        NavigationLink("Top up this loan") { TopupView(loan: loan) }
                            .accessibilityIdentifier("topup-\(loan.loanId)")
                    }
                }
            }
            .overlay { if model.isLoading { ProgressView() } }
            .navigationTitle("My loans")
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }
}
