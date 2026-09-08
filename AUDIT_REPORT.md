# Adversarial code-integrity report

**Audit date:** September 8, 2026  
**Scope:** all Swift source, tests, Xcode project metadata, StoreKit configuration, privacy manifest, localizations, Python fixture and release documents in this package.  
**Method:** line-by-line and holistic adversarial review by one expert agent, primary-source review, targeted hardening, and static/fixture checks available on Linux.

## Release verdict

**NOT RELEASE-APPROVED.** The source has been materially hardened, but “100% integrity” or “no bugs” cannot be established without compiling in Xcode, running on iPhone/iPad, using StoreKit sandbox/TestFlight and testing representative real televisions and hostile network conditions.

## Material corrections completed

- Replaced per-request URLSession creation with a long-lived, bounded transport; rejected redirects and oversized responses.
- Replaced unconditional self-signed-certificate acceptance with trust-on-first-use pin continuity, explicit reset, session rebuild and missing/changed-pin AUTH denial.
- Serialized URLSession replacement/access and associated trust failures with a unique request identifier to avoid cross-request attribution and transport data races.
- Bound Keychain token IDs to validated endpoints rather than attacker-controlled SSDP USN/UUID values.
- Strictly validated canonical private IPv4 addresses, ports, SSDP status/target/location/header sizes and pairing numeric/token inputs.
- Added cancellation/operation identity, deterministic lifecycle reset and a 12-action age-limited FIFO.
- Added rollback of the token and certificate pin if local persistence fails after the television accepts a pairing PIN.
- Moved selected-TV metadata into device-only Keychain storage, enforced endpoint-derived IDs, serialized management operations against all network entry points, and surfaced rollback cleanup failures.
- Suspended in-flight remote work before forget/identity-reset maintenance, made unverified-purchase alerts reflect any remaining verified access, and stripped Unicode control/format scalars from TV-provided error details.
- Enforced trial access inside the model as well as the view; expiry/background closes stale sheets and blocks network entry points.
- Added StoreKit 2 verified-entitlement handling, transaction updates, restore, pending/cancel/error states, a free non-consumable 24-hour trial and separate one-time non-consumable unlock.
- Added a fail-closed state for owned but unverified StoreKit transactions; the app does not invite a second purchase while verification is unresolved.
- Added explicit no-renewal/no-auto-charge disclosure and StoreKit-localized pricing.
- Corrected the product name to avoid using a third-party brand in the App Store title.
- Added complete source localizations and policy/listing packs for English, Spanish (Mexico/Latin America) and French (Canada).
- Added parser, address, protocol and trial-policy adversarial unit cases.
- Added non-paywalled controls to forget one television or remove every saved TV address, token, certificate identity and app-generated client UUID.
- Replaced connected-multicast discovery with one bound UDP socket that retries M-SEARCH and receives unicast replies on the originating port.
- Bound SSDP `LOCATION` hosts to the actual datagram source address before presenting or persisting a discovered endpoint.
- Corrected Home to SmartCast code 4/15, separated Play and Pause, and mapped text-entry space to documented SmartCast code 52.
- Cleared uncommitted certificate candidates on abandoned pairing paths and copied URLSession configuration before hardening transport policy.
- Increased the mute target, darkened the primary action colour for contrast, and made legal/connection links adapt vertically at large text sizes.

## Known residual risks and gates

| Severity | Open item | Required evidence/remediation |
|---|---|---|
| Blocker | Signed archive not yet validated | Debug compilation and the full unit suite passed in GitHub Actions on Xcode; require the warning-as-error Release build, analyzer, signed archive and App Store validation |
| Blocker | No iPhone/iPad or compatible TV available | Physical device matrix covering pairing, commands, power, forget/reset/remove-all/re-pair and localization |
| High | Corrected SSDP socket still lacks physical-network evidence | Packet capture and physical iPhone/iPad testing across representative routers and firmware |
| High | IPv4-only implementation | Validate accessory behavior on dual-stack/IPv6-only/NAT64; add safe IPv6/zone support if real TVs advertise it |
| High | First-contact TOFU cannot prevent an active relay | Hostile-LAN test; disclose limitation; consider vendor-verifiable identity if one becomes available |
| High | Firmware/protocol is not vendor-supported | Maintain a tested firmware/model matrix and conservative listing claims |
| High | Trial uses device wall clock against Apple-signed purchase date | Exact tamper-resistant 24-hour enforcement is not possible offline; test clock/time-zone/reboot changes and use trusted server time/state if cheat resistance is required |
| Medium | Pin, token and selected-device metadata are separate Keychain writes | Add a persisted pairing journal or composite recoverable record; fault-inject process termination after each commit |
| Medium | Session reset relies on `invalidateAndCancel()` to stop requests admitted just before replacement | Add an async transport generation/task registry and prove reset quiescence under concurrent send/reset stress |
| Medium | Accessibility/layout not rendered here | Xcode previews plus physical/simulator tests at largest sizes and VoiceOver |
| Compliance | Multicast entitlement, export answer, App Privacy and trademark rights | Account-holder/Apple/legal confirmation before submission |
| Compliance | Store-account forms and product setup remain incomplete | Complete current App Store Connect privacy, age rating, IAP, agreements, regional and review forms against the signed binary |

## Evidence limits

The Python fixture passed 11 HTTP protocol contract scenarios, including 250 sequential command requests. The current GitHub Actions evidence also includes a successful Debug simulator build and full unit-test run. The fixture still does not exercise the production Swift HTTPS/TOFU transport, certificate challenges, StoreKit sandbox, multicast entitlement, physical iOS lifecycle or real firmware. Static localization parity remains structural rather than native-speaker or rendered-layout certification.

Follow every gate in `RELEASE_CHECKLIST.md`; unresolved items must not be silently converted into launch claims.
