# Release integrity checklist

No release is approved until every BLOCKED item below has evidence attached to the release record.

## Source and identity

- [x] Generic customer-facing name **TV Remote Control**; vendor brand limited to compatibility context.
- [x] Bundle ID `com.worksbienstudios.clearmote` reconciled with product IDs.
- [x] English, Spanish (Latin America) and French (Canada) string-key and placeholder parity checked statically.
- [x] App has no third-party SDK or backend dependency in source.
- [ ] BLOCKED: confirm legal entity, copyright, support URL, privacy URL and trademark wording.
- [x] Source and release workflows committed to private repository `lrodeveloperr/tv-remote-control-ios`.

## Build and automated verification

- [x] Debug simulator build completed with Xcode on hosted macOS.
- [ ] BLOCKED: warning-as-error Release simulator build and analyzer must be green on the final commit.
- [x] Lifecycle/access unit cases added for local-data management without entitlement, access revocation and denied discovery.
- [x] All current Swift unit tests executed successfully in Xcode after correcting the boolean pairing-token parser defect.
- [ ] BLOCKED: add/execute UI lifecycle cases for background, trial expiry and stale sheets.
- [ ] BLOCKED: run StoreKit configuration tests for available, active, 24-hour boundary, expired, pending, cancelled, refunded/revoked, lifetime and restore states.
- [ ] BLOCKED: run Thread Sanitizer, Address Sanitizer and Xcode Static Analyzer as applicable.
- [ ] BLOCKED: archive, validate and inspect the exact submitted binary for entitlements, privacy manifest and unexpected SDKs.
- [x] Python protocol fixture self-test completed in the supplied environment; this is not a Swift/iOS stress test.
- [x] Static localization, JSON/XML and project-reference checks included in `AUDIT_REPORT.md`.

## Network and hardware

- [ ] BLOCKED: multicast entitlement approved and present in signed build.
- [x] Discovery redesigned around one bound UDP socket with retries; advertised host is required to match the datagram source.
- [ ] BLOCKED: validate SSDP reply reception and packet flow on physical iPhone/iPad.
- [ ] BLOCKED: test dual-stack, IPv6-only/NAT64, VPN, guest Wi-Fi/client isolation and multiple-TV networks.
- [ ] BLOCKED: pair, forget, reset identity, re-pair and reconnect on real TVs using ports 7345 and 9000 where applicable.
- [ ] BLOCKED: validate every command on representative firmware/apps, especially Play/Pause, text entry and power behavior.
- [ ] BLOCKED: test malformed/oversized responses and rapid/concurrent button presses against the Swift client on Apple hardware.

## Security and privacy

- [x] Canonical private IPv4 and port allowlist enforced.
- [x] Redirects rejected; response sizes, header sizes, device count and command queue bounded.
- [x] AUTH token is not sent when the certificate pin is absent or changed.
- [x] First-contact certificate is committed only after successful PIN pairing; explicit reset rebuilds the TLS session.
- [x] A failed local write after accepted pairing attempts rollback of the token and certificate pin; cleanup failures are detected and surfaced with recovery instructions.
- [x] Device ID and SSDP persistence IDs are validated/derived instead of trusting arbitrary values.
- [x] Selected-TV metadata, tokens and certificate identities use device-only Keychain accessibility; deletion errors are surfaced.
- [x] Forget, identity-reset and remove-all maintenance suspend active discovery/pairing/verification/command work before local security changes.
- [x] TV-provided error details remove ASCII and Unicode control/format scalars before display.
- [x] A non-paywalled management screen can forget one TV or request deletion of all saved TV addresses, tokens, certificate identities and the app-generated client UUID.
- [ ] BLOCKED: perform an independent penetration test on a hostile LAN, including SSDP spoofing and first-use MITM/relay scenarios.
- [ ] BLOCKED: confirm privacy policy/App Privacy answers against the final binary.

## Accessibility and localization

- [x] Text sheet made scrollable/adaptive; quick actions adapt at Accessibility Dynamic Type.
- [ ] BLOCKED: test iPhone SE/smallest supported iPhone and representative iPads in portrait/landscape.
- [ ] BLOCKED: test largest Dynamic Type, VoiceOver order, Reduce Motion/Transparency, contrast and switch/keyboard access.
- [ ] BLOCKED: native-speaker and legal review for Spanish (Mexico) and French (Canada).

## Public support and policy pages

- [x] TV Remote Control is present in the live support selector and routes requests to `info@worksbienstudios.com`.
- [x] Final privacy, terms, purchase and localized policy pages are published at stable public HTTPS URLs.
- [ ] BLOCKED: enter the exact live URLs in App Store Connect and verify them in the saved version record.

## App Store Connect

- [ ] BLOCKED: accept agreements; complete tax/banking as required.
- [ ] BLOCKED: create free 1-day Trial non-consumable and one-time Full Remote Unlock non-consumable using exact IDs.
- [ ] BLOCKED: set localized IAP names/descriptions and storefront price; upload IAP review screenshot.
- [ ] BLOCKED: reserve localized names; upload descriptions, keywords, privacy/terms URLs and signed-build screenshots.
- [ ] BLOCKED: complete age-rating, content-rights, encryption/export-compliance and App Privacy questionnaires from current rules.
- [ ] BLOCKED: submit products and binary together, then preserve the exact reviewer notes in `APP_STORE.md`.
