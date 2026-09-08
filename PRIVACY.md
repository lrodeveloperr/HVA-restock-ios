# TV Remote Control Privacy Policy

**Effective date: September 8, 2026**

TV Remote Control does not send personal data to WorksBien Studios Inc. The app has no developer-operated account, advertising, analytics, tracking or cloud service.

## Local network

The app uses local-network access to discover and communicate directly with a compatible television. Discovery responses are untrusted network input. The user selects a television and completes a TV-displayed PIN flow before control. Commands and typed text travel from the Apple device to the selected television; WorksBien Studios does not receive them. The television manufacturer’s software processes that traffic under its own practices.

During first pairing, compatible TVs present a self-signed local certificate that cannot be verified through a public certificate authority for the TV’s private address. The app temporarily trusts only the selected private endpoint for the TV-displayed PIN exchange, then stores that certificate identity after the PIN succeeds. This protects later connection continuity but cannot independently prove the TV’s identity against an active attacker during the first pairing. Pair only on a private network you trust.

## Stored on the device

The selected TV’s private IPv4 address, port and display name, the television-issued pairing token, and the saved TV certificate identity are stored as device-only iOS Keychain items. The app-generated client UUID and haptic preference are stored in local preferences. Users can use **Forget This TV** to request removal of one saved TV’s address, token and certificate identity. **Remove All Saved TV Data** requests removal of every saved address, pairing token, certificate identity and the app-generated TV client UUID. A separate identity-reset action is provided when the TV certificate changes.

## Purchases

Apple processes the free 1-day Trial and optional one-time Full Remote Unlock. The app reads verified StoreKit product ID, product type, purchase date, current entitlement/revocation state and localized price to decide whether remote access is available. The trial lasts 24 hours, does not renew and makes no automatic charge. The developer does not receive payment-card details.

## Sharing and retention

WorksBien Studios does not receive, sell or share the local data described above. Retention on the device continues until the user uses the app’s removal controls, iOS removes the applicable storage, or the device is erased. Apple and the television vendor may separately process data as part of their services/devices.

## Children

The app is not designed to collect information from children and does not knowingly send user information to WorksBien Studios.

## Changes and contact

Material changes will be reflected by updating this policy and its effective date.

WorksBien Studios Inc.  
`https://worksbienstudios.com/customerservice`

TV Remote Control is independent and is not affiliated with or endorsed by Vizio, Inc.
