#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AirdropIOS"
BUNDLE_ID="dev.swiftSolanaKit.examples.AirdropIOS"
MINIMUM_IOS_VERSION="17.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

case "$(uname -m)" in
    arm64)
        TRIPLE="arm64-apple-ios${MINIMUM_IOS_VERSION}-simulator"
        ;;
    x86_64)
        TRIPLE="x86_64-apple-ios${MINIMUM_IOS_VERSION}-simulator"
        ;;
    *)
        echo "Unsupported host architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"

swift build \
    --package-path "$PACKAGE_DIR" \
    --triple "$TRIPLE" \
    --sdk "$SDKROOT"

BIN_PATH="$(swift build \
    --package-path "$PACKAGE_DIR" \
    --triple "$TRIPLE" \
    --sdk "$SDKROOT" \
    --show-bin-path)/$APP_NAME"

APP_DIR="$PACKAGE_DIR/.build/ios-simulator/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

cp "$BIN_PATH" "$APP_DIR/$APP_NAME"
mkdir -p "$APP_DIR/Base.lproj"
cat > "$APP_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>$MINIMUM_IOS_VERSION</string>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
    </dict>
</dict>
</plist>
PLIST

cat > "$APP_DIR/Base.lproj/LaunchScreen.storyboard" <<STORYBOARD
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" initialViewController="LaunchScreenViewController">
    <scenes>
        <scene sceneID="LaunchScreenScene">
            <objects>
                <viewController id="LaunchScreenViewController" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="LaunchScreenView">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <color key="backgroundColor" systemColor="systemBackgroundColor"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="LaunchScreenFirstResponder" sceneMemberID="firstResponder"/>
            </objects>
        </scene>
    </scenes>
    <resources>
        <systemColor name="systemBackgroundColor">
            <color white="1" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>
        </systemColor>
    </resources>
</document>
STORYBOARD

codesign --force --sign - "$APP_DIR" >/dev/null

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && /(Booted|Shutdown)/ { print $2; exit }')"
fi

if [[ -z "$DEVICE_ID" ]]; then
    echo "No available iPhone simulator was found." >&2
    exit 1
fi

xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
open -a Simulator
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_ID" "$APP_DIR"
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "Launched $APP_NAME on simulator $DEVICE_ID"
