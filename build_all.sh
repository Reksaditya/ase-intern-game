#!/usr/bin/env bash
# Export The Last Gatekeeper for Windows, Linux, macOS and Android into bin/.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

GODOT="${GODOT:-godot}"
APP_NAME="TheLastGatekeeper"

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "error: Godot not found. Install Godot 4.7.2 or set GODOT=/path/to/godot." >&2
	exit 1
fi

echo "Using $("$GODOT" --version | head -n 1)"

mkdir -p bin/windows bin/linux bin/macos bin/android
touch bin/.gdignore

# Refresh the import cache so newly added or changed assets are exported.
"$GODOT" --headless --path . --import

# Android release signing key. This is a local development key, not a Play Store key.
if [[ ! -f keystore/release.keystore ]]; then
	if ! command -v keytool >/dev/null 2>&1; then
		echo "error: keytool not found. Install a JDK to build the Android APK." >&2
		exit 1
	fi
	echo "Generating development Android keystore..."
	mkdir -p keystore
	keytool -genkeypair -v \
		-keystore keystore/release.keystore \
		-alias thelastgatekeeper \
		-keyalg RSA -keysize 2048 -validity 10000 \
		-storepass thelastgatekeeper -keypass thelastgatekeeper \
		-dname "CN=The Last Gatekeeper, OU=Game, O=ASE, L=Jakarta, ST=Jakarta, C=ID"
fi

export_platform() {
	local preset="$1"
	local output="$2"
	local label="$3"

	echo
	echo "==> Exporting ${label} -> ${output}"
	"$GODOT" --headless --path . --export-release "$preset" "$output"
	if [[ ! -s "$output" ]]; then
		echo "error: ${label} export did not produce ${output}" >&2
		exit 1
	fi
}

export_platform "Windows Desktop" "bin/windows/${APP_NAME}.exe" "Windows (x86_64)"
export_platform "Linux" "bin/linux/${APP_NAME}.x86_64" "Linux (x86_64)"
export_platform "macOS" "bin/macos/${APP_NAME}.zip" "macOS (universal)"
export_platform "Android" "bin/android/${APP_NAME}.apk" "Android (arm64-v8a + armeabi-v7a)"

# APK v4 signature sidecar is only useful for `adb install --incremental`.
rm -f "bin/android/${APP_NAME}.apk.idsig"

echo
echo "==> SHA-256 checksums"
(
	cd bin
	sha256sum \
		"windows/${APP_NAME}.exe" \
		"linux/${APP_NAME}.x86_64" \
		"macos/${APP_NAME}.zip" \
		"android/${APP_NAME}.apk" > SHA256SUMS.txt
	cat SHA256SUMS.txt
)

echo
echo "Done. Builds are in ${ROOT_DIR}/bin/"
