# Validation record

## Automated source checks completed

- Package and source structure enumerated successfully.
- `AppConfiguration.json` parsed successfully with `jq`.
- Swift source delimiter balance check passed for all source and test files.
- Dependency scan found no package dependency, third-party SDK import, analytics SDK, advertising SDK, account service, or publisher-cloud integration.
- Sixteen domain and CSV XCTest cases cover boundaries, malformed and oversized input, aliases, quoting, CRLF, embedded newlines, exact issue line numbers, duplicate counting, deterministic keys, free-limit overflow, spreadsheet formula neutralization, round trips, and quantity/reversal overflow and underflow.
- Fifteen executable HTML adversarial fixtures pass for hostile text, collision-free IDs, stale/deleted targets, renamed-item reversal, quantity boundaries, render-state coverage, commit-time duplicate and free-limit enforcement, interrupted unlock flow, repeated imports, atomic import rollback, and safe CSV export.
- The approved screen structure and visual system were held constant; patches were restricted to state, validation, persistence boundaries, accessibility labels, and error behavior.

## Integrity corrections from the adversarial review

- Reversal now targets immutable item IDs, rejects deleted/stale records, and cannot overflow on `Int.min`.
- Every quantity path enforces `0...999,999`; suggested quantities and free-limit arithmetic are overflow-safe.
- CSV reads are capped before full allocation, malformed quotes are rejected, physical source lines remain correct across embedded newlines, and exports neutralize spreadsheet formulas without losing literal apostrophes on round trip.
- Imports calculate their real new-item count, merge repeat matches consistently, write activity for every row, and roll back as one atomic change on failure.
- Concurrent exports use isolated temporary paths, stale editor references fail safely, and the settings-to-import handoff no longer depends on scheduler timing.
- The HTML preview escapes all user-controlled markup, preserves search focus, prevents rapid ID collisions, revokes export URLs, and keeps an interrupted import intact through the one-time unlock preview.

## Requires Xcode on macOS

This workspace does not include Swift, Xcode, the iOS SDK, or StoreKit test services. Before distribution:

1. Build with Xcode 16 or later for an iOS 17 simulator and physical device.
2. Run `HVACRestockCoreTests`.
3. Exercise VoiceOver, Dynamic Type, dark mode, compact-width layouts, and iPad layout.
4. Test purchase, pending purchase, cancellation, restore, revocation, and offline launch with a StoreKit configuration and App Store sandbox account.
5. Test CSV import/export through Files, Mail, AirDrop, and at least one spreadsheet app.
6. Replace the placeholder policy URLs and verify App Store Connect metadata.
