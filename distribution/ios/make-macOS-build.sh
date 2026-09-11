#!/bin/bash

# convert_macho.sh - Convert iOS Mach-O binary to Mac Catalyst format
# This script replicates the functionality of the Swift Macho.convertMacho() method

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-macho-binary>"
    exit 1
fi

MACHO_PATH="$1"

if [ ! -f "$MACHO_PATH" ]; then
    echo "Error: File not found: $MACHO_PATH"
    exit 1
fi

echo "Converting MachO at $MACHO_PATH"

TEMP_FILE=$(mktemp)
cp "$MACHO_PATH" "$TEMP_FILE"

echo "Stripping MachO..."
# Extract ARM64 slice from fat binary if needed
lipo "$TEMP_FILE" -thin arm64 -output "$TEMP_FILE" 2>/dev/null || true

echo "Replacing version command..."
# Replace version command with Mac Catalyst build version
# LC_BUILD_VERSION (0x32), platform MACCATALYST (6), minos 11.0.0, sdk 14.0.0
vtool -set-build-version maccatalyst 11.0 14.0 -replace -output "$TEMP_FILE" "$TEMP_FILE"

echo "Replacing instances of @rpath dylibs..."

RPATH_LIBS=$(otool -L "$TEMP_FILE" | grep "@rpath" | awk '{print $1}' | sed 's/@rpath\///')

if [ -n "$RPATH_LIBS" ]; then
    while IFS= read -r dylib; do
        if [ -n "$dylib" ]; then
            OLD_PATH="@rpath/$dylib"
            NEW_PATH="/System/iOSSupport/usr/lib/swift/$dylib"
            echo "  Replacing $OLD_PATH -> $NEW_PATH"
            install_name_tool -change "$OLD_PATH" "$NEW_PATH" "$TEMP_FILE" 2>/dev/null || true
        fi
    done <<< "$RPATH_LIBS"
else
    echo "  No @rpath dylibs found"
fi

echo "Writing revised MachO..."

mv "$TEMP_FILE" "$MACHO_PATH"

echo "Successfully converted $MACHO_PATH"
