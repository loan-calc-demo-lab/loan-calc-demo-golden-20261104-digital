# Digital Platforms – mobile app (baseline)

The Digital Platforms domain's iOS app for the agentic SDLC demo (SwiftUI, iOS 18+). It calls the Lending loan service.

- Tabs: **My loans** (the signed-in customer's existing loans) and **Loan quote** (quote with APR).
- The demo has no sign-in: the app acts for the fictional demo customer `CUST-1001` (`Session.swift`).
- Screen content is data (`QuoteSummary`, `LoanSummary`), so screen requirements are unit-testable.
- API address: build setting `LOAN_API_BASE_URL` (default `http://localhost:8080`); personal settings in
  `ios/Config/Local.xcconfig` (not committed).
- Test: `xcodebuild test -project ios/LoanCalculator.xcodeproj -scheme LoanCalculator -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Low-level designs go to `design/`.
