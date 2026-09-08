# TV Remote Control for iPhone and iPad

A native SwiftUI remote for compatible Vizio SmartCast televisions. The app talks directly to the selected television over the local network; it has no developer-operated backend, advertising, analytics or account system.

## Commerce

The App Store download is free. StoreKit 2 supplies two non-consumable products:

- `com.worksbienstudios.clearmote.trial.1day` — free **1-day Trial**, providing all remote features for 24 hours after its verified App Store transaction.
- `com.worksbienstudios.clearmote.lifetime` — optional **Full Remote Unlock**, a one-time purchase whose entitlement does not expire. The UI always uses Apple's localized `displayPrice`.

The trial does not renew and does not automatically charge. Eligible purchases can be restored for the same Apple Account. There are no subscriptions.

## Open in Xcode

1. Open `VizioRemote.xcodeproj` in Xcode 16 or later.
2. Select the `VizioRemote` target and confirm bundle ID `com.worksbienstudios.clearmote`, signing team and version.
3. Open `Products.storekit` and confirm both non-consumables validate.
4. Obtain Apple's multicast-networking entitlement for the production App ID before relying on automatic SSDP discovery.
5. Run unit tests and StoreKit tests on iPhone and iPad destinations.
6. Run on a physical iPhone/iPad and a representative compatible TV before making hardware claims.

Deployment target: iOS 17.0.

## Hardware-free checks

The built-in **Try Demo TV** path uses PIN `1234` and exercises pairing, buttons, text input, reconnection and reset without a television. The Python fixture can run a protocol contract self-test with:

```bash
python3 MockTV/mock_smartcast.py --self-test
```

These checks do not prove that SSDP, self-signed TLS, pairing or commands work on real firmware.

## Security and limitations

- Only canonical private IPv4 addresses and SmartCast ports 7345/9000 are accepted.
- Redirects are rejected, responses are bounded, commands use a bounded FIFO, and selected-TV metadata, tokens and TV certificate pins are device-only Keychain items.
- The first PIN pairing uses trust-on-first-use for the TV's self-signed certificate; later certificate changes are blocked until the user explicitly resets the saved identity.
- SSDP is an untrusted hint. A user must recognize and select the TV, and successful PIN pairing is required.
- IPv6-only/NAT64 behavior, multicast reply handling, command mappings, power-state behavior and firmware coverage remain physical-device release gates.
- Vizio's local SmartCast API is not a vendor-supported public SDK and may change.

No third-party source code is vendored. Request shapes were independently implemented with public protocol references, including `exiva/Vizio_SmartCast_API`.

See `RELEASE_CHECKLIST.md`, `APP_STORE.md` and `AUDIT_REPORT.md` before submission.
