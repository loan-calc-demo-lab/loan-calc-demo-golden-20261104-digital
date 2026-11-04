import Foundation

nonisolated enum Percent {
    /// REQ-007: percentages as the customer sees them, one decimal place, e.g. "10.2%".
    static func oneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_IE"))) + "%"
    }
}

nonisolated enum Money {
    /// Euro amounts as the customer sees them, e.g. "€856.07".
    static func eur(_ amount: Double) -> String {
        amount.formatted(.currency(code: "EUR").locale(Locale(identifier: "en_IE")))
    }
}
