# App Store submission pack

Status: **prepared, not submission-ready**. Items marked BLOCKED require App Store Connect, Xcode, physical Apple hardware or a compatible television.

## Product record

- App Store name: **TV Remote Control**
- Subtitle: **Simple Wi-Fi Controls**
- Home Screen name: **TV Remote**
- Bundle ID: `com.worksbienstudios.clearmote`
- Version/build: confirm from the archive before submission
- Platforms: iPhone and iPad, iOS 17+
- Primary category: Utilities
- Secondary category: Entertainment
- App price: Free
- Age rating recommendation: 4+; complete the current questionnaire from actual content
- Copyright: 2026 WorksBien Studios Inc.
- Support URL: `https://worksbienstudios.com/customerservice`
- Privacy URL: BLOCKED until `PRIVACY.md` is published at a stable public HTTPS URL
- Terms: Apple Standard Licensed Application EULA plus the disclosures in `TERMS.md`

The generic name avoids implying vendor ownership. Mention Vizio/SmartCast only in compatibility prose, never in the title, subtitle, icon or keyword field unless written authorization is obtained.

## In-app purchases

| Product | Product ID | Type | App Store setup | Access |
|---|---|---|---|---|
| 1-day Trial | `com.worksbienstudios.clearmote.trial.1day` | Non-consumable | Price tier 0 / Free | All remote features for 24 hours from verified purchase date |
| Full Remote Unlock | `com.worksbienstudios.clearmote.lifetime` | Non-consumable | Recommended US storefront price: $2.99 | Full remote access; entitlement does not expire |

The trial is explicit opt-in, does not renew and causes no automatic downstream charge. The optional unlock is purchased separately. The app displays the StoreKit localized price, not a hard-coded amount. Configure both products and their English, Spanish (Mexico) and French (Canada) localizations in App Store Connect, submit them with the app version, and upload an IAP review screenshot showing the actual purchase screen.

## Promotional text

Try every remote feature free for one day, then keep access with one optional purchase. No ads, accounts or subscriptions.

## Description

Control a compatible Vizio SmartCast television from your iPhone or iPad over your local network.

TV Remote Control keeps the interface focused on everyday controls: navigation, volume, channels, input selection, playback and basic text entry. Use automatic discovery when available or enter the TV's local IPv4 address manually.

FEATURES

• Direction pad with a large OK button  
• Volume, mute and channel controls  
• Home, back, menu and input controls  
• Play/Pause button (availability varies by TV app and firmware)  
• Basic Latin keyboard entry  
• Manual IP fallback  
• Built-in Demo TV for exploring the interface

TRY IT, THEN PAY ONCE

Start the free 1-day Trial to use every remote feature for 24 hours. Access stops when the trial ends. The trial does not renew and you will not be charged automatically. Keep access with the optional one-time Full Remote Unlock. The App Store shows the price before confirmation. There are no subscriptions.

PRIVATE BY DESIGN

• No account  
• No advertising or analytics SDKs  
• No developer-operated cloud service  
• Commands travel directly between this device and the selected television  
• Selected-TV metadata, pairing token and saved TV certificate identity use the device-only iOS Keychain

COMPATIBILITY

Requires a compatible Vizio SmartCast television and a working local network. Firmware, model, network isolation and power settings can affect availability. Power-on is not guaranteed when the TV is unreachable. IPv6-only networks are not currently supported; the TV must expose a private IPv4 address. Legacy Vizio Internet Apps televisions are not supported.

TV Remote Control is an independent application and is not affiliated with or endorsed by Vizio, Inc. Vizio and SmartCast are trademarks of their owner and are used only to describe compatibility.

## Keywords

`controller,volume,keyboard,input,channel,navigation,media,smart television`

Do not repeat words from the title/subtitle and do not add vendor or competitor trademarks without approval. Re-check the live 100-character limit in App Store Connect.

## App Review notes

This app controls compatible televisions directly over the local network and therefore normally depends on external hardware. A complete hardware-independent demo is included.

Review path:

1. On the purchase screen, acquire the free **1-day Trial** using the sandbox account. It unlocks every feature for exactly 24 hours, does not renew and creates no automatic charge.
2. Tap **Try Demo TV**.
3. Enter PIN **1234**.
4. Exercise the remote buttons and basic text entry.
5. Open Settings to test **Restore Purchases**, **Forget This TV** or **Remove All Saved TV Data**.

The optional **Full Remote Unlock** is a separate one-time non-consumable. There are no subscriptions, ads, accounts or backend servers. Automatic discovery uses SSDP multicast; manual private-IPv4 entry is available. The multicast entitlement must be present in the submitted build.

## App Privacy answers

Based on the current source, select **Data Not Collected** only after the release binary is checked for added SDKs. The developer does not receive TV addresses, commands, tokens, certificate pins or payment details. Apple processes StoreKit transactions. The app locally reads verified product ID, product type, purchase date, revocation/current-entitlement state and localized price to enforce access.

Tracking: No. Advertising: No. Account: No. Third-party analytics: No.

## Export compliance

The app uses Apple URLSession/TLS and Keychain APIs; it contains no custom cryptographic implementation. Confirm the current App Store Connect encryption questionnaire with counsel/current Apple documentation. Set `ITSAppUsesNonExemptEncryption` only after that determination; it is intentionally not guessed in the project.

## Screenshot plan

- iPhone and iPad: purchase screen with exact trial/no-auto-charge/one-time-unlock disclosure
- iPhone and iPad: connection screen with Find My TV, manual IP and Demo TV
- iPhone and iPad: main remote
- iPhone and iPad: keyboard/settings as useful
- Localize visible copy for Spanish (Mexico) and French (Canada)

Use screenshots from the final signed build. Generated prototypes are not evidence for App Review or the IAP review screenshot.

## Submission blockers

- Xcode build, analyzer, unit/UI/StoreKit tests and release archive have not been run in this Linux environment.
- Real iPhone/iPad and real compatible-TV pairing/command/power testing is incomplete.
- SSDP unicast reply handling, dual-stack/NAT64 behavior and firmware coverage are unverified.
- Multicast entitlement approval is unverified.
- App Store agreements, products, localizations, prices, tax/banking, screenshots and review submission require the account holder.
- Public privacy/terms URLs are not yet confirmed.
- The current support page must add TV Remote Control to its app selector and verify the contact path.
- Trademark/compatibility wording needs the publisher's final legal approval.
