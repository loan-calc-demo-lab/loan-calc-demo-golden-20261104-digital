import SwiftUI

/// REQ-008: top up an existing loan – amount and term, indicative offer, accept, confirmation.
struct TopupView: View {
    let loan: Loan
    @State private var model = TopupViewModel()

    var body: some View {
        Form {
            if let result = model.acceptResult {
                Section("Top-up done") {
                    rows(model.confirmationRows)
                    Text(result.withdrawalReminder).font(.footnote).accessibilityIdentifier("withdrawalReminder")
                }
            } else {
                Section("Your top-up") {
                    TextField("Top-up amount (€)", text: $model.amountText).keyboardType(.numberPad)
                        .accessibilityIdentifier("amountField")
                    TextField("Term (months)", text: $model.termText).keyboardType(.numberPad)
                        .accessibilityIdentifier("termField")
                    Button("Show my offer") { Task { await model.loadOffer(loanId: loan.loanId) } }
                        .disabled(model.isLoading)
                        .accessibilityIdentifier("showOffer")
                }
                if let offer = model.offer {
                    Section(offer.label) {
                        rows(model.summaryRows)
                    }
                    Section {
                        Button("Accept offer") { Task { await model.acceptOffer(offerId: offer.offerId) } }
                            .disabled(model.isLoading)
                            .accessibilityIdentifier("acceptOffer")
                    }
                }
            }
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red).accessibilityIdentifier("topupError")
            }
        }
        .overlay { if model.isLoading { ProgressView() } }
        .navigationTitle("Top up \(loan.loanId)")
    }

    @ViewBuilder private func rows(_ rows: [QuoteRow]) -> some View {
        ForEach(rows) { row in
            VStack(alignment: .leading, spacing: 2) {
                LabeledContent(row.label, value: row.value)
                    .font(row.weight == .headline ? .headline : .body)
                if let explanation = row.explanation {
                    Text(explanation).font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier(row.id)
        }
    }
}
