import SwiftUI

/// REQ-002: month-by-month repayment schedule.
struct ScheduleView: View {
    let schedule: [ScheduleRow]

    var body: some View {
        List(schedule) { row in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Month \(row.month)").font(.headline)
                    Spacer()
                    Text(Money.eur(row.payment)).font(.headline)
                }
                HStack {
                    Text("Principal \(Money.eur(row.principal))")
                    Spacer()
                    Text("Interest \(Money.eur(row.interest))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text("Balance after payment \(Money.eur(row.balance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .navigationTitle("Repayment schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ScheduleView(schedule: [
            ScheduleRow(month: 1, payment: 856.07, principal: 814.40, interest: 41.67, balance: 9185.60),
            ScheduleRow(month: 2, payment: 856.07, principal: 817.79, interest: 38.28, balance: 8367.81),
        ])
    }
}
