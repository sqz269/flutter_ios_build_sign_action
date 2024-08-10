# Assert to check if the script is running on MacOS
if [ "$(uname)" != "Darwin" ]; then
    echo "This script is only supported on MacOS"
    exit 1
fi

# Check if Debug flag is set
if [ -z "$DEBUG" ]; then
    DEBUG=false
fi

# Debug print function
function debug_print() {
    if [ "$DEBUG" = true ]; then
        echo "$1"
    fi
}

# Identify the P12 Cert name from the keychain
P12_CERTIFICATE_NAME=$(security find-identity -v -p codesigning | grep -o '"[^"]*"' | head -1 | sed 's/"//g')
debug_print "P12_CERTIFICATE_NAME: $P12_CERTIFICATE_NAME"

# Identify the Provisioning Profile UUID
PROVISIOING_PROFILE_UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< $(/usr/bin/security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision))
debug_print "PROVISIOING_PROFILE_UUID: $PROVISIOING_PROFILE_UUID"

# Identify the Provisioning Profile Team ID
PROVISIOING_PROFILE_TEAM_ID=$(/usr/libexec/PlistBuddy -c "Print TeamIdentifier:0" /dev/stdin <<< $(/usr/bin/security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision))
debug_print "PROVISIOING_PROFILE_TEAM_ID: $PROVISIOING_PROFILE_TEAM_ID"

# Check if the Apple Developer Team ID is set, if it's not set then use the Provisioning Profile Team ID
if [ -z "$APPLE_DEVELOPER_TEAM_ID" ]; then
    echo "APPLE_DEVELOPER_TEAM_ID not set, using TeamIdentifier from Provisioning Profile"
    APPLE_DEVELOPER_TEAM_ID=$PROVISIOING_PROFILE_TEAM_ID
fi

# Identify the App Bundle ID
APP_BUNDLE_ID=$(cat ios/Runner.xcodeproj/project.pbxproj | grep -o "PRODUCT_BUNDLE_IDENTIFIER = [^;]*" | head -1 | cut -d ' ' -f 3)
debug_print "APP_BUNDLE_ID: $APP_BUNDLE_ID"

# Must ensure that the ios/Podfile is present
if [ ! -f ios/Podfile ]; then
    echo "'ios/Podfile' not found. Is iOS properly enabled for the flutter project? Ensure the iOS project is created on a MacOS machine."
    exit 1
fi

# Ensure that the Podfile is properly 

xcodebuild -resolvePackageDependencies -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release

echo "Building and signing the iOS app..."
# archive
xcodebuild \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -sdk iphoneos \
    -configuration Release \
    -archivePath $PWD/build/Runner.xcarchive \
    clean archive \
    CODE_SIGN_STYLE=Manual \
    PROVISIONING_PROFILE_SPECIFIER="$PROVISIOING_PROFILE_UUID" \
    DEVELOPMENT_TEAM="$APPLE_DEVELOPER_TEAM_ID" \
    CODE_SIGN_IDENTITY="$P12_CERTIFICATE_NAME"

# Create ExportOptions.plist if there is none specified
if [ -z "$EXPORT_OPTIONS_PLIST" ]; then
echo "Creating ExportOptions.plist..."
cat <<EOF > ExportOptions.plist
<?xml version="1.0" encoding="UTF-8"?>
<dict>
    <key>provisioningProfiles</key>
    <dict>
        <key>$APP_BUNDLE_ID</key>
        <string>$PROVISIOING_PROFILE_UUID</string>
    </dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>signingCertificate</key>
    <string>$P12_CERTIFICATE_NAME</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>$APPLE_DEVELOPER_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
EXPORT_OPTIONS_PLIST=$PWD/ExportOptions.plist

else
    echo "Using the specified ExportOptions.plist..."
    # Check if the specified ExportOptions.plist exists
    if [ ! -f $EXPORT_OPTIONS_PLIST ]; then
        echo "The specified ExportOptions.plist does not exist."
        exit 1
    fi

    # Replace template values in double brackets in the ExportOptions.plist
    # Mapped as the following:
    # - {{APP_BUNDLE_ID}} -> $APP_BUNDLE_ID
    # - {{PROVISIOING_PROFILE_UUID}} -> $PROVISIOING_PROFILE_UUID
    # - {{P12_CERTIFICATE_NAME}} -> $P12_CERTIFICATE_NAME
    # - {{APPLE_DEVELOPER_TEAM_ID}} -> $APPLE_DEVELOPER_TEAM_ID
    sed -i '' "s/{{APP_BUNDLE_ID}}/$APP_BUNDLE_ID/g" $EXPORT_OPTIONS_PLIST
    sed -i '' "s/{{PROVISIOING_PROFILE_UUID}}/$PROVISIOING_PROFILE_UUID/g" $EXPORT_OPTIONS_PLIST
    sed -i '' "s/{{P12_CERTIFICATE_NAME}}/$P12_CERTIFICATE_NAME/g" $EXPORT_OPTIONS_PLIST
    sed -i '' "s/{{APPLE_DEVELOPER_TEAM_ID}}/$APPLE_DEVELOPER_TEAM_ID/g" $EXPORT_OPTIONS_PLIST
fi

echo "Exporting IPA..."
# Export IPA
xcodebuild \
    -exportArchive \
    -archivePath $PWD/build/Runner.xcarchive \
    -exportPath $PWD/build/IPA \
    -exportOptionsPlist $EXPORT_OPTIONS_PLIST

echo "iOS app signed successfully!"

# find the ipa file name created
IPA_FILE_NAME=$(ls $PWD/build/IPA/*.ipa)
echo "IPA_FILE_NAME: $IPA_FILE_NAME"

# # echo "Upoloading the IPA to App Store Connect..."
# # upload IPA to App Store Connect
# xcrun altool --upload-app -f $IPA_FILE_NAME -t ios -u $APPLE_DEVELOPER_EMAIL -p @env:APP_SPECIFIC_PASSWORD

