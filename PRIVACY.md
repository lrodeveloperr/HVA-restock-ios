# Privacy Policy for Remote for Vizio TV Controller

**Effective:** 9 September 2026<br>
**Applies to:** Remote for Vizio TV Controller 1.0 for iPhone and iPad

WorksBien Studios Inc. ("WorksBien Studios," "we," "us," or "our") publishes Remote for Vizio TV Controller (the "App"). This policy explains what the App processes, what stays on the device, and what may be processed separately by Apple or a television manufacturer.

## 1. Plain-language summary

- The App has no WorksBien account, developer-operated cloud service, advertising, analytics, tracking or third-party crash-reporting SDK.
- WorksBien Studios does not receive TV addresses, pairing tokens, certificate identities, remote commands or typed text during ordinary use.
- The App uses local-network access to discover and communicate directly with a compatible television selected by the user.
- Apple separately processes App Store transactions and may process platform diagnostics under Apple's terms and device settings.
- A television manufacturer separately processes traffic received by its television under its own practices.

## 2. Local-network information

Discovery responses are untrusted network input. The App may process a television's private IPv4 address, port, display name and device identifier to show discovery results and connect. The user selects a television and completes a television-displayed PIN flow before control. Commands and typed text travel from the Apple device to the selected television over the local network; WorksBien Studios does not receive them.


During first pairing, compatible TVs present a self-signed local certificate that cannot be verified through a public certificate authority for the TV’s private address. The App temporarily trusts only the selected private endpoint for the television-displayed PIN exchange, then stores that certificate identity after the PIN succeeds. This protects later connection continuity but cannot independently prove the TV’s identity against an active attacker during the first pairing. Pair only on a private network you trust.

The App does not support control through a WorksBien server. Network equipment, the television and its manufacturer may observe or process local-network traffic according to their own operation and policies.

## 3. Information stored on the device

The selected television's private IPv4 address, port and display name, the television-issued pairing token, and the saved television certificate identity are stored as device-only iOS Keychain items. The App-generated client UUID and haptic preference are stored in local preferences.

Use **Forget This TV** to request removal of one saved television's address, token and certificate identity. Use **Remove All Saved TV Data** to request removal of all saved addresses, pairing tokens, certificate identities and the App-generated TV client UUID. If the television's certificate changes, use **Forget This TV** (or **Remove All Saved TV Data**) and pair again only on a private network you trust.

## 4. Purchases

Apple processes the free 1-day Trial and optional one-time Full Remote Unlock. The App reads verified StoreKit product ID, product type, purchase date, current entitlement or revocation state, and localized price to decide whether remote access is available. The trial lasts 24 hours, does not renew and makes no automatic charge. WorksBien Studios does not receive full payment-card or bank details.

Apple may provide transaction, product, storefront, refund, tax, sales and aggregate performance information under Apple's terms.

## 5. Diagnostics, TestFlight and support

Apple may provide crash or diagnostic information according to device and developer-console settings. The App contains no third-party crash-reporting SDK and is not designed to place pairing tokens or typed remote text in diagnostic messages.

For TestFlight builds, Apple may make tester contact details, feedback, screenshots, device/build information and diagnostics available under TestFlight terms and tester choices. Do not include pairing tokens, private network details or sensitive television content in feedback.

If you contact support, we receive the email address and information you choose to send. Send only the App version/build, device and iOS/iPadOS version, a neutral error message and non-sensitive reproduction steps.

## 6. Sharing, sale, tracking and retention

WorksBien Studios does not receive, sell or share the local information described above and does not use it for cross-app tracking. Local retention continues until the user uses the App's removal controls, iOS removes the applicable storage, the App is uninstalled subject to Keychain behaviour, or the device is erased.

We may retain support correspondence and Apple-issued business records only as reasonably needed for support, security, legal, tax, accounting or dispute purposes. Apple, GitHub, email providers, network providers and television manufacturers are independent providers for their services.

## 7. Privacy requests, children and security

WorksBien Studios cannot access, correct or delete information it never receives. Use the App's controls for saved television data. For information actually held by WorksBien Studios, contact **info@worksbienstudios.com**. We may verify identity or authority.

The App is not directed to children and is not designed to send children's information to WorksBien Studios. No device or network is completely secure. Use only televisions and networks you are authorized to control, protect the Apple device with appropriate access controls, and do not rely on the App as the sole emergency, safety-critical or accessibility-essential remote.

## 8. Changes and contact

We may update this policy when the App, law or data practices change. The current version is published at this URL with its effective date. Material changes will receive an appropriate App or store notice where required.

Operator and privacy contact: **WorksBien Studios Inc.**, **info@worksbienstudios.com**. Customer service: [worksbienstudios.com/customerservice](https://worksbienstudios.com/customerservice).

Remote for Vizio TV Controller is independent and is not affiliated with or endorsed by Vizio, Inc.
