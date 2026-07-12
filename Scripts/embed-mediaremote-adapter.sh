#!/bin/sh
# Xcode build phase: compiles the vendored MediaRemoteAdapter framework from
# source and embeds it, plus the adapter perl script, into the app bundle.
# Uses only Apple's toolchain — building Halo needs nothing but Xcode.
set -eu

VENDOR_DIR="$SRCROOT/Vendor/mediaremote-adapter"
FW_DIR="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Frameworks/MediaRemoteAdapter.framework"
# macOS frameworks use a versioned layout: the real files live in
# Versions/A/ and the top level holds symlinks to them.
FW_BINARY="$FW_DIR/Versions/A/MediaRemoteAdapter"
RESOURCES_DIR="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"

mkdir -p "$FW_DIR/Versions/A/Resources" "$RESOURCES_DIR"

# Recompile only when a vendored source file is newer than the built binary.
if [ ! -f "$FW_BINARY" ] || [ -n "$(find "$VENDOR_DIR" -newer "$FW_BINARY" -print -quit)" ]; then
    echo "Compiling MediaRemoteAdapter.framework from vendored source"
    xcrun clang \
        -dynamiclib -fobjc-arc -O2 \
        -arch arm64 -arch x86_64 \
        -mmacosx-version-min="$MACOSX_DEPLOYMENT_TARGET" \
        -I"$VENDOR_DIR/include" -I"$VENDOR_DIR/src" \
        -framework Foundation -framework AppKit \
        -framework UniformTypeIdentifiers \
        -install_name "@rpath/MediaRemoteAdapter.framework/MediaRemoteAdapter" \
        -o "$FW_BINARY" \
        "$VENDOR_DIR"/src/adapter/*.m \
        "$VENDOR_DIR"/src/private/*.m \
        "$VENDOR_DIR"/src/utility/*.m

    # Embedded frameworks must carry an Info.plist describing the bundle.
    cat > "$FW_DIR/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.vandenbe.MediaRemoteAdapter</string>
	<key>CFBundleName</key>
	<string>MediaRemoteAdapter</string>
	<key>CFBundleExecutable</key>
	<string>MediaRemoteAdapter</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>0.7.6</string>
	<key>CFBundleVersion</key>
	<string>0.7.6</string>
</dict>
</plist>
PLIST

    # Top-level symlinks pointing into Versions/A, per framework convention.
    ln -sfh A "$FW_DIR/Versions/Current"
    ln -sfh Versions/Current/MediaRemoteAdapter "$FW_DIR/MediaRemoteAdapter"
    ln -sfh Versions/Current/Resources "$FW_DIR/Resources"

    # Ad-hoc sign the framework (Xcode signs the enclosing app afterwards).
    codesign --force --sign - "$FW_DIR"
fi

cp "$VENDOR_DIR/bin/mediaremote-adapter.pl" "$RESOURCES_DIR/"
