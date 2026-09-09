# App Store submission pack

Status: **TestFlight build uploaded and Apple-validated; App Store review intentionally not submitted**. Build `2609081633.5` is processed as `VALID`, the version record and non-media metadata are complete, and the build is assigned to the internal testing group. Physical hardware checks and final media/account-owner actions remain before production submission.

## Product record

- App Store name: **Remote for Vizio TV Controller**
- Subtitle: **WiFi Keyboard, Volume & More**
- Home Screen name: **TV Remote**
- Bundle ID: `com.worksbienstudios.clearmote`
- Version/build: release version / TestFlight build `2609081633.5`
- Platforms: iPhone and iPad, iOS 17+
- Primary category: Utilities
- Secondary category: Entertainment
- App price: Free
- Age rating recommendation: 4+; complete the current questionnaire from actual content
- Copyright: 2026 WorksBien Studios Inc.
- Support URL: `https://worksbienstudios.com/customerservice`
- Marketing URL: `https://worksbienstudios.com/apps/tv-remote-control`
- Privacy URL: `https://lrodeveloperr.github.io/privacy-policy/tv-remote-control/privacy/`
- Supplemental terms URL: `https://lrodeveloperr.github.io/privacy-policy/tv-remote-control/terms/`
- Terms: Apple Standard Licensed Application EULA plus the disclosures in `TERMS.md`

The exact-intent title covers remote, Vizio, TV and controller; “for Vizio” states compatibility and avoids logos, official claims or brand styling. Keep the independence disclaimer prominent and do not repeat third-party marks in the subtitle or keyword field.

## In-app purchases

| Product | Product ID | Type | App Store setup | Access |
|---|---|---|---|---|
| 1-day Trial | `com.worksbienstudios.clearmote.trial.1day` | Non-consumable | Price tier 0 / Free | All remote features for 24 hours from verified purchase date |
| Full Remote Unlock | `com.worksbienstudios.clearmote.lifetime` | Non-consumable | Recommended US storefront price: $2.99 | Full remote access; entitlement does not expire |

The trial is explicit opt-in, does not renew and causes no automatic downstream charge. The optional unlock is purchased separately. The app displays the StoreKit localized price, not a hard-coded amount. Both products and their English, Spanish (Mexico) and French (Canada) localizations are configured in App Store Connect; the lifetime unlock is priced at US $2.99. Upload an IAP review screenshot showing the actual purchase screen before submission. The products remain in `MISSING_METADATA` until their required review media is attached.

## Promotional text

Try every remote feature free for one day, then keep access with one optional purchase. No ads, separate app account or subscription.

## Description

Control a compatible Vizio SmartCast television from your iPhone or iPad over your local network.

TV Remote Control keeps the interface focused on everyday controls: navigation, volume, channels, input selection, playback and basic text entry. Use automatic discovery when available or enter the TV's local IPv4 address manually.

FEATURES

• Direction pad with a large OK button  
• Volume, mute and channel controls  
• Home, back, menu and input controls  
• Separate Play and Pause controls (availability varies by TV app and firmware)  
• Basic Latin keyboard entry  
• Automatic same-Wi-Fi discovery
• Built-in Demo TV for exploring the interface

TRY IT, THEN PAY ONCE

Start the free 1-day Trial to use every remote feature for 24 hours. Access stops when the trial ends. The trial does not renew and you will not be charged automatically. Keep access with the optional one-time Full Remote Unlock. The App Store shows the price before confirmation. There are no subscriptions.

PRIVATE BY DESIGN

• No separate app account  
• No advertising or analytics SDKs  
• No developer-operated cloud service  
• Commands travel directly between this device and the selected television  
• Selected-TV metadata, pairing token and saved TV certificate identity use the device-only iOS Keychain

COMPATIBILITY

Requires a compatible Vizio SmartCast television and a working local network. Firmware, model, network isolation and power settings can affect availability. Power-on is not guaranteed when the TV is unreachable. IPv6-only networks are not currently supported; the TV must expose a private IPv4 address. Legacy Vizio Internet Apps televisions are not supported.

TV Remote Control is an independent application and is not affiliated with or endorsed by Vizio, Inc. Vizio and SmartCast are trademarks of their owner and are used only to describe compatibility.

## Keywords

`smart,input,channel,navigation,media,power,dpad,buttons,pairing`

Do not repeat words from the title/subtitle and do not add vendor or competitor trademarks without approval. Re-check the live 100-character limit in App Store Connect.

## App Review notes

This app controls compatible televisions directly over the local network and therefore normally depends on external hardware. A complete hardware-independent demo is included.

Review path:

1. On the purchase screen, acquire the free **1-day Trial** using the sandbox account. It unlocks every feature for exactly 24 hours, does not renew and creates no automatic charge.
2. Tap **Try Demo TV**.
3. Enter PIN **1234**.
4. Exercise the remote buttons and basic text entry.
5. Open Settings to test **Restore Purchases**, **Forget This TV** or **Remove All Saved TV Data**.

The optional **Full Remote Unlock** is a separate one-time non-consumable. There are no subscriptions, ads, separate app accounts or backend servers. Automatic discovery browses the declared `_googlecast._tcp` Bonjour service and confirms a compatible SmartCast control port. There is no manual-address setup and no custom multicast entitlement.

## App Privacy answers

Based on the current source, select **Data Not Collected** only after the release binary is checked for added SDKs. The developer does not receive TV addresses, commands, tokens, certificate pins or payment details. Apple processes StoreKit transactions. The app locally reads verified product ID, product type, purchase date, revocation/current-entitlement state and localized price to enforce access.

Tracking: No. Advertising: No. Separate app account: No. Third-party analytics: No.

## Export compliance

The app uses Apple URLSession/TLS and Keychain APIs and contains no custom cryptographic implementation. The project declares `ITSAppUsesNonExemptEncryption = false`. Reconfirm this answer against the final binary and Apple’s current export-compliance questionnaire before submission.

## Screenshot plan

- iPhone and iPad: purchase screen with exact trial/no-auto-charge/one-time-unlock disclosure
- iPhone and iPad: connection screen with Find My TV and Demo TV
- iPhone and iPad: main remote
- iPhone and iPad: keyboard/settings as useful
- Localize visible copy for Spanish (Mexico) and French (Canada)

A six-image iPhone/iPad screenshot set was generated from the release UI and visually reviewed. Attach the final-device exports to the App Store version and use the purchase-screen image for IAP review media before submission.

## Submission blockers

- Final source commit `a95b6e579d3dd217f0932d4f3b938e617d458478` passed project/localization validation, Debug and warning-as-error Release builds, static analysis and the complete Xcode unit/StoreKit recovery suite.
- The copied release source was signed, archived, Apple-validated and uploaded as TestFlight build `2609081633.5`; App Store Connect reports `processingState=VALID`.
- The app record now contains localized metadata, categories, age rating, content rights, copyright, manual release selection, reviewer details and the processed build. No App Store review submission was created.
- The free trial and lifetime IAP records/localizations exist and the lifetime price is US $2.99; required IAP review media still needs to be attached.
- A six-image iPhone/iPad screenshot set is ready and visually reviewed but still needs to be attached to the App Store record.
- The build is assigned to `TV Remote Control Internal Testers`; the Account Holder must be enabled as an internal tester in App Store Connect before it appears in that person's TestFlight app. Apple's API rejected assigning the existing email-only beta-tester identity.
- Real iPhone/iPad and compatible-TV discovery, pairing, command, power and text-entry testing remain incomplete.
- Multicast entitlement presence in the final signed binary, IPv6-only/NAT64 behavior and representative firmware coverage remain unverified.
- Agreements and tax/banking status remain publisher-account checks.
- The public privacy, terms, purchase and support pages are live; reconfirm them immediately before submission.
- Trademark/compatibility wording needs the publisher's final legal approval.
