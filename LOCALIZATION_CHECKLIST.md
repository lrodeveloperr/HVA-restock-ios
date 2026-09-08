# Localization checklist

## Source-complete

- [x] English (`en`), Latin American Spanish (`es-419`) and Canadian French (`fr-CA`) app resources included.
- [x] Home Screen names: **TV Remote**, **Control de TV**, **Télécommande TV**.
- [x] App Store names: **TV Remote Control**, **Control remoto de TV**, **Télécommande TV**.
- [x] Trial, one-time unlock, restore, pending/error and no-auto-charge disclosures localized.
- [x] Pairing, security-identity reset, validation and accessibility strings localized.
- [x] Key sets and format placeholders statically checked for parity.
- [x] Privacy policies and terms supplied in all three languages.
- [x] Store metadata and IAP display text supplied for English, Spanish (Mexico) and French (Canada).

## BLOCKED: Xcode/device QA

- [ ] Build Debug and Release with current Xcode; treat warnings as errors for release review.
- [ ] Run tests with scheme language English, Spanish and French (Canada).
- [ ] Inspect every screen on a small iPhone and iPad portrait/landscape.
- [ ] Test default and largest Accessibility Dynamic Type; verify no clipping or horizontal scrolling.
- [ ] Test VoiceOver labels, rotor order, focus, pronunciation and actions.
- [ ] Confirm local-network permission copy in all languages.
- [ ] Complete Demo TV flow with PIN `1234` in all languages.
- [ ] Verify price/currency formatting under US, Mexico and Canada storefront test accounts.
- [ ] Verify trial-available, active, expired, pending, revoked/refunded and lifetime states.
- [ ] Capture localized screenshots from the signed candidate build.
- [ ] Obtain professional/native-speaker review of Spanish (Mexico) and French (Canada) legal/marketing copy.

## App Store Connect

- [ ] Confirm all three app names are available and meet current metadata rules.
- [ ] Create both non-consumables with matching product IDs and localized display text.
- [ ] Keep price/trial terms out of the app name, subtitle and keywords.
- [ ] Upload localized metadata, screenshots and IAP review screenshot.
- [ ] Publish matching privacy/terms pages and enter stable HTTPS URLs.
- [ ] Add TV Remote Control to the public support page and verify its contact path.
- [ ] Reconcile the final binary, privacy manifest, App Privacy answers, listing and policies immediately before submission.
