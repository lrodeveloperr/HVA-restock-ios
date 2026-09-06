#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
preview_file="$(cd "$project_dir/.." && pwd)/HVAC-Restock-iOS-Full-Preview.html"
node_bin="${CODEX_PRIMARY_RUNTIME_NODE:-node}"

jq -e . "$project_dir/Sources/HVACRestockApp/Resources/AppConfiguration.json" >/dev/null

"$node_bin" -e '
const fs = require("fs");
const vm = require("vm");
const html = fs.readFileSync(process.argv[1], "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
if (scripts.length !== 1) throw new Error(`Expected one inline script, found ${scripts.length}`);
new vm.Script(scripts[0][1]);
' "$preview_file"

"$node_bin" "$project_dir/Tests/HTMLPreviewIntegrityTests.js"

if rg -n 'import (Firebase|Amplitude|Mixpanel|GoogleMobileAds|FacebookSDK)|\.package\(' "$project_dir" --glob '*.swift' --glob 'Package.swift'; then
  echo "Unexpected third-party dependency or telemetry SDK found." >&2
  exit 1
fi

echo "Static integrity validation: PASS"
