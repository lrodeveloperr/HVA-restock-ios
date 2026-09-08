# Stress and break-test checklist

## StoreKit/access

- Trial purchase available → active → exact 24-hour boundary → expired.
- Device clock backward/forward, time-zone change, reboot and long offline period.
- Pending Ask to Buy, cancellation, unverified transaction, refund/revocation and interrupted purchase.
- Lifetime purchase, reinstall/restore on same Apple Account and restore failure while Settings is open.
- Trial expiry while remote, keyboard, Settings, pairing and discovery UI are open; verify all network actions stop.

## Lifecycle/concurrency

- Background during discovery, pairing start, PIN completion, local pairing-data persistence, verification, command send and StoreKit sheet.
- Rapidly press 1,000 mixed buttons; verify the bounded queue never exceeds 12 pending actions, entries older than two seconds are dropped and UI remains responsive.
- Alternate connect/cancel/forget/re-pair quickly; verify stale tasks never overwrite the current device/state.
- Trigger Forget This TV and targeted identity reset while each command type is awaiting a response; verify the old command cannot restore connection state or overwrite the maintenance result.
- Delay every secure-storage deletion, then attempt discovery, manual connection, pairing, verification and command entry while removal is running; verify all are rejected until removal finishes.
- Make cancelled pairing/discovery fakes ignore cancellation and complete late; verify operation IDs prevent them from changing newer state.
- Memory warning, 100 foreground/background cycles and network transitions during every operation.

## Hostile network/response

- Spoofed SSDP response, empty/duplicate/control-filled/oversized headers, `2000` status-prefix attack, wrong ST, public/noncanonical host, wrong scheme/port.
- Oversized/chunked/slow response, malformed JSON, boolean/fractional/overflow challenge values and control-filled error strings.
- Redirect attempts with and without AUTH; confirm no AUTH forwarding.
- First-contact MITM, changed certificate, missing pin with saved AUTH, forget/reset then immediate re-pair, and concurrent different certificates for one endpoint.
- Multiple TVs, duplicate advertisements, DHCP address changes, guest/client-isolated Wi-Fi, VPN/routed RFC1918 and NAT64/IPv6-only networks.

## Device/UI/accessibility

- Smallest supported iPhone and representative iPads, portrait/landscape and split view.
- English, Spanish (Mexico) and French (Canada); largest Accessibility Dynamic Type and VoiceOver.
- Long TV names, extreme localized App Store prices and 128-character text-entry boundary.
- Denied/revoked local-network permission, locked Keychain state, corrupted endpoint metadata, forced post-PIN persistence failure and storage deletion failures; verify endpoint-ID binding and that token/certificate rollback or cleanup-failure recovery is surfaced.

Record OS, device, TV model/firmware, network topology, build SHA, result, logs and screenshot/video for each run.
