# HVAC Restock for iOS

Native SwiftUI source for a private, offline HVAC truck-stock utility.

## Product contract

- One-tap `Used` action decreases an item's quantity by one.
- Items at or below their restock threshold appear automatically in Restock.
- Suggested purchase quantity is `max(0, restockTo - onHand)`.
- Every quantity mutation writes an activity event that can be reversed once.
- Ten active items are free; item 11 requires the non-consumable lifetime unlock.
- Existing records, activity, reversal, and CSV export are never blocked.
- No accounts, ads, analytics, publisher cloud, customer records, scheduling, or photographs.

## Native engine

The app uses only Apple platform frameworks:

- SwiftData for device-local persistence
- StoreKit 2 for the one-time non-consumable purchase
- UniformTypeIdentifiers and native share/file pickers for CSV
- SwiftUI and the approved GoodUse shell for presentation

There is no third-party SDK or third-party source dependency. The app-specific code is therefore suitable for the owner's commercial application subject to Apple's normal SDK and App Store terms.

## Xcode integration

1. In Xcode 16 or later, create an iOS App project with SwiftUI and Swift.
2. Choose **File → Add Package Dependencies → Add Local** and select this folder.
3. Add the package product `HVACRestock` to the app target.
4. Replace the generated app entry point with `AppHost/HVACRestockApp.swift`. Its import is `HVACRestockApp`, the module exposed by the package product.
5. Add `AppHost/Assets.xcassets` to the app target and select its `AppIcon` set as the target's App Icons Source. The icon is used only by iOS and the App Store; it is not shown inside the app UI.
6. Create a non-consumable App Store Connect product whose identifier matches `PurchaseManager.productID`.
7. Set the localized App Store price to the approved one-time tier (US reference price: $14.99).
8. Confirm the published privacy and terms URLs in `AppLinks.swift` return the HVAC Restock documents.

For CI/TestFlight, install XcodeGen and run `xcodegen generate`. The generated project is `HVACRestock.xcodeproj`, the production scheme is `HVACRestock`, the bundle identifier is `com.worksbienstudios.hvacrestock`, and the included privacy manifest declares the app-only `UserDefaults` reason used by first-run state.

The package targets iOS 17 because SwiftData is the production persistence engine.

## Shell boundary

`GoodUseShell.swift` is the approved shell layer. App-specific models, state, workflow, validation, persistence, purchase logic, CSV handling, and screens live outside it.

## Validation boundary

Pure domain and CSV tests plus executable HTML adversarial fixtures are included. Run `Scripts/validate_integrity.sh` for the checks available on any development machine. The current Linux workspace does not contain Xcode or the Apple SwiftUI/SwiftData frameworks, so final iOS compilation, StoreKit sandbox purchase verification, simulator rendering, and accessibility inspection remain Xcode-stage checks.

`Samples/HVAC-Inventory-Template.csv` is a ready-to-import template for smoke testing the workflow. See `VALIDATION.md` for the completed checks and release gate.
