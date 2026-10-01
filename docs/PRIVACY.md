# Data boundaries

This document describes the published source, not a legal certification or a guarantee about a differently configured build. The analysis pipeline operates on-device. The surrounding product integrates subscription and optional analytics services.

## What is stored or transmitted

| Data | Location / destination | Purpose |
| --- | --- | --- |
| Latest full-resolution capture | App cache directory | Current analysis/report photo; replaced by the next capture |
| Scan thumbnails | App Application Support directory | Local history and comparisons, maximum dimension 480 px |
| Scores, findings, history | App UserDefaults records | Restoring reports and showing trends |
| Quota IDs and timestamps | Device-only Keychain items | Rolling five-scan/24-hour allowance |
| Onboarding and preferences | Local preferences | Product personalization and settings |
| Subscription state and SDK identity | RevenueCat / App Store flow | Purchase, entitlement, and restore handling |
| Allowlisted interaction metadata | Mixpanel after optional consent | Product usage and reliability measurements |
| Shared report | Destination selected by the user | Explicit report sharing |

Capture and thumbnail writes use atomic JPEG storage with complete file protection until first user authentication. Cache files can be purged by iOS. The source does not establish a universal exclusion from system backups for all local data; assess backup behavior as part of a release review.

## Analytics consent and filtering

`AppAnalytics` has unknown, allowed, and denied consent states. Unknown or denied consent prevents tracking. Enabling consent does not replay events from an earlier declined session. Withdrawal opts the SDK out and clears its local queue/identity through the SDK API.

The app's payload allowlist excludes photos, face measurements, scores, names, answer text, file paths, arbitrary dictionaries, and raw error messages. It accepts a bounded set of interaction properties such as screen/action, selected plan, numeric error code, and analysis duration. The tests inject an offline event sink to verify consent and filtering without network delivery.

Automatic event collection, session replay, feature flags, and IP-based geolocation are disabled in the configured analytics path. RevenueCat's app user ID supplies a pseudonymous correlation identity. No registration or email is required to use the app.

Debug configures analytics only when explicitly launched with `LOOKGRADE_ANALYTICS_QA=1`. Release still needs consent. Development, sandbox, and production events carry different environment values; client event logs are not a billing ledger or proof of money collected.

## Deletion boundaries

Local history and photo controls remove their associated app records. The independent quota ledger retains minimal recent usage records so deleting history does not reset the allowance. Keychain persistence and provider records have a different lifecycle from the visible history.

Deleting local data does not delete events that were already delivered to an external service. Profile exposes the privacy support identifier for a user-initiated request. Provider-side retention and deletion must be operated separately. The UI never silently emails a user identifier.

## Configuration and publication

The checked-in service values are client SDK/ingestion configuration, not server administrative keys. Configure your own projects before sending test events or evaluating your own catalog. Signing keys, provisioning profiles, server credentials, and raw customer exports do not belong in Git.

The included [legal-site source and deployment guide](../LegalSite/README.md) and `PrivacyInfo.xcprivacy` describe part of the release configuration. GitHub Pages publishes privacy, terms, and support from this repository at <https://numann44.github.io/LookGrade/>. `LegalLinks.swift` uses these URLs. This does not update installed app binaries, App Store Connect metadata, App Store Privacy disclosures, account ownership, or provider-side policies; the deployment guide records the release migration steps.
