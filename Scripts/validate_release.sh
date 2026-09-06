#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./Scripts/validate_integrity.sh

required=(project.yml AppHost/Info.plist AppHost/PrivacyInfo.xcprivacy AppHost/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)
for path in "${required[@]}"; do
  [[ -f "$path" ]] || { echo "Missing release file: $path" >&2; exit 1; }
done

if grep -R -n -E 'example\.com|worksbien\.com/hvac-restock|YOUR_|PLACEHOLDER' AppHost Sources project.yml; then
  echo "Release placeholder found." >&2
  exit 1
fi

grep -q 'com.worksbienstudios.hvacrestock' project.yml
grep -q 'com.worksbienstudios.hvacrestock.lifetime' Sources/HVACRestockApp/PurchaseManager.swift
grep -q 'lrodeveloperr.github.io/privacy-policy/hvac-restock/privacy/' Sources/HVACRestockApp/AppLinks.swift
grep -q 'NSPrivacyAccessedAPICategoryUserDefaults' AppHost/PrivacyInfo.xcprivacy
grep -q 'CA92.1' AppHost/PrivacyInfo.xcprivacy

echo "Release source validation: PASS"
