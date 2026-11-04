import SwiftUI

/// Loan quote screen.
/// REQ-001 monthly payment, REQ-003 input validation, REQ-004 upfront fee, REQ-005 zero-rate loans, REQ-006 reset.
struct QuoteView: View {
    @State private var model = QuoteViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Your loan") {
                    input("Amount (€)", text: $model.principalText, field: "principal", keyboard: .decimalPad)
                    input("Interest rate (%)", text: $model.rateText, field: "annual_rate_pct", keyboard: .decimalPad)
                    input("Term (months)", text: $model.termText, field: "term_months", keyboard: .numberPad)
                    input("Arrangement fee (€)", text: $model.feeText, field: "upfront_fee", keyboard: .decimalPad, placeholder: "0")
                }

                Section {
                    HStack(spacing: 12) {
                        Button {
                            Task { await model.calculate() }
                        } label: {
                            if model.isLoading {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Calculate").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isLoading)
                        .accessibilityIdentifier("calculate")

                        // REQ-006: start again from the starting values.
                        Button {
                            model.reset()
                        } label: {
                            Text("Reset").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isLoading || !model.canReset)
                        .accessibilityIdentifier("reset")
                    }
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if let message = model.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let quote = model.quote {
                    Section("Your quote") {
                        // The rows and their order come from QuoteSummary, where they are tested.
                        ForEach(QuoteSummary.rows(for: quote)) { row in
                            LabeledContent {
                                Text(row.value)
                            } label: {
                                Text(row.label)
                                if let explanation = row.explanation {
                                    Text(explanation)
                                }
                            }
                            .font(row.weight == .headline ? .headline : .body)
                            .accessibilityIdentifier(row.id)
                        }
                        NavigationLink("Repayment schedule") {
                            ScheduleView(schedule: quote.schedule)
                        }
                    }
                }
            }
            .navigationTitle("Loan Calculator")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private func input(_ label: String, text: Binding<String>, field: String,
                       keyboard: UIKeyboardType, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(label) {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                    .accessibilityIdentifier(field)
            }
            if let message = model.error(for: field) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("\(field)_error")
            }
        }
    }
}

#Preview {
    QuoteView()
}
