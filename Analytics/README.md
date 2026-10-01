# Product analytics

LookGrade uses an explicit, consent-gated Mixpanel integration. The source is [AppAnalytics.swift](../FaceRate/App/AppAnalytics.swift); the data boundary is documented in [PRIVACY.md](../docs/PRIVACY.md).

## Collection rules

- Unknown or denied consent suppresses events. Declining analytics does not prevent app use.
- Opt-in does not replay previously declined activity. Profile can withdraw consent.
- Photos, face measurements, scores, names, answer text, file paths, and raw error messages are excluded from app payloads.
- Properties pass through a bounded allowlist. Automatic events, session replay, feature flags, and IP-derived geolocation are disabled.
- The RevenueCat app user ID is used as a pseudonymous correlation ID.
- Normal Debug runs send no analytics. `LOOKGRADE_ANALYTICS_QA=1` explicitly enables Debug SDK initialization; use an owned test project.

## Event dictionary

| Area | Events | Main context |
| --- | --- | --- |
| Lifecycle | App Opened, App Backgrounded | Session, sequence, source |
| Navigation | Screen Viewed, Screen Left, Navigation Action | Screen, destination, foreground duration |
| Exposure | Section Viewed | Screen/section, once per visit |
| Onboarding | Onboarding Action, Onboarding Completed | Step/action, selection count, presence of a name; no answer values |
| Agreement | Privacy Agreement Action | Action and selected state |
| Scan access | Scan Requested, Scan Blocked | Source and reason |
| Camera | Camera Action, Camera State Changed | Action, permission/state, numeric error code |
| Analysis | Analysis Started/Completed/Failed/Cancelled | Mode, duration, numeric error code |
| Report | Report Action | Action and locked state |
| Paywall | Viewed, Plans Loaded/Failed, Plan Selected, Close Tapped, Left | Visit/variant, product/package/offering, displayed price/currency |
| Private offer | Intro Viewed, Viewed, Unavailable, Leave Warning, Kept | Paywall context and action |
| Purchase | Started/Completed/Cancelled/Failed | Entitlement access, period type, sandbox status |
| Restore | Started/Completed/Failed | Access, numeric error code |
| Settings | Settings Action | Action |

Every event includes schema, app version/build/language, environment, and session context. The Swift enum contains exact event names; the table groups related names for readability.

## Interpretation

Production analysis should filter `environment = production`; keep development and sandbox traffic separate. Consent means the dataset represents opted-in activity, not all users. Foreground screen duration differs from total elapsed wall-clock time. Backgrounding is not proof of deliberate exit, and missing events can result from offline delivery or process termination.

Client-observed Purchase Completed is not collected revenue. It may be a trial. Displayed package price is not money received. Subscription renewals, refunds, and billing retries that happen outside the app require provider-side records.

Private dashboard/query URLs and operational account handoffs are excluded from this public snapshot. This folder contains the implementation dictionary and a [separate simulator UI-test harness](UITests/README.md), not customer exports.
