#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SE_CS_PATH="src/UI/Logic/Config/Se.cs"
TEMPLATE_APP="installer/macBundle/SubtitleEdit.app"

VERSION_LINE=$(grep -E 'public static string Version.*=.*"v[0-9]' "$SE_CS_PATH")
if [ -z "$VERSION_LINE" ]; then
    echo "Could not extract version from $SE_CS_PATH" >&2
    exit 1
fi

VERSION=$(echo "$VERSION_LINE" | sed -n 's/.*"v\([^"]*\)".*/\1/p')
DEFAULT_APP_NAME="Subtitle Edit Beta ${VERSION}"
APP_NAME="${APP_NAME:-$DEFAULT_APP_NAME}"
BUNDLE_ID="${BUNDLE_ID:-dk.nikse.subtitleedit.beta}"
CONFIGURATION="${CONFIGURATION:-Release}"
RID="${RID:-osx-arm64}"
BUILD_OUTPUT="${BUILD_OUTPUT:-publish/macos-beta-${RID}}"
USE_PUBLISH="${USE_PUBLISH:-1}"
SELF_CONTAINED="${SELF_CONTAINED:-1}"
PUBLISH_SINGLE_FILE="${PUBLISH_SINGLE_FILE:-1}"
COPY_SYSTEM_FFMPEG="${COPY_SYSTEM_FFMPEG:-0}"
COPY_FRAMEWORKS_FROM_APP="${COPY_FRAMEWORKS_FROM_APP:-}"

PUBLISH_DIR="$ROOT_DIR/publish/macos-beta-${RID}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
EXECUTABLE_PATH="$APP_DIR/Contents/MacOS/SubtitleEdit"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"

rm -rf "$PUBLISH_DIR" "$APP_DIR"
mkdir -p "$DIST_DIR"

if [ "$USE_PUBLISH" = "1" ]; then
    echo "Publishing $RID build..."
    publish_args=(
        src/UI/UI.csproj
        -c "$CONFIGURATION"
        -r "$RID"
        -o "$PUBLISH_DIR"
    )

    if [ "$SELF_CONTAINED" = "1" ]; then
        publish_args+=(--self-contained true)
    else
        publish_args+=(--self-contained false)
    fi

    if [ "$PUBLISH_SINGLE_FILE" = "1" ]; then
        publish_args+=(-p:PublishSingleFile=true)
    fi

    dotnet publish "${publish_args[@]}"

    find "$PUBLISH_DIR" -name "*.pdb" -type f -delete
    SOURCE_DIR="$PUBLISH_DIR"
else
    case "$BUILD_OUTPUT" in
        /*) SOURCE_DIR="$BUILD_OUTPUT" ;;
        *) SOURCE_DIR="$ROOT_DIR/$BUILD_OUTPUT" ;;
    esac
    echo "Using existing build output: $SOURCE_DIR"
    if [ ! -f "$SOURCE_DIR/SubtitleEdit" ]; then
        echo "Executable not found in $SOURCE_DIR" >&2
        exit 1
    fi
fi

echo "Creating app bundle: $APP_DIR"
cp -R "$TEMPLATE_APP" "$APP_DIR"

chmod +x installer/macBundle/update-plist-version.sh
./installer/macBundle/update-plist-version.sh "$SE_CS_PATH" "$PLIST_PATH"

/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleDocumentTypes:0:LSHandlerRank Alternate" "$PLIST_PATH" || true
/usr/libexec/PlistBuddy -c "Set :CFBundleDocumentTypes:1:LSHandlerRank Alternate" "$PLIST_PATH" || true

find "$APP_DIR/Contents/MacOS" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
mkdir -p "$FRAMEWORKS_DIR"

if [ "$SELF_CONTAINED" = "1" ] && [ "$PUBLISH_SINGLE_FILE" = "1" ]; then
    cp "$SOURCE_DIR/SubtitleEdit" "$APP_DIR/Contents/MacOS/"
    find "$SOURCE_DIR" -maxdepth 1 -name "*.dylib" -type f -exec cp {} "$APP_DIR/Contents/MacOS/" \;
else
    cp -R "$SOURCE_DIR/"* "$APP_DIR/Contents/MacOS/"
fi

chmod +x "$EXECUTABLE_PATH"

if [ "$COPY_SYSTEM_FFMPEG" = "1" ] && command -v ffmpeg >/dev/null 2>&1; then
    cp "$(command -v ffmpeg)" "$APP_DIR/Contents/MacOS/ffmpeg"
    chmod +x "$APP_DIR/Contents/MacOS/ffmpeg"
fi

if [ -n "$COPY_FRAMEWORKS_FROM_APP" ] && [ -d "$COPY_FRAMEWORKS_FROM_APP/Contents/Frameworks" ]; then
    cp -R "$COPY_FRAMEWORKS_FROM_APP/Contents/Frameworks/." "$FRAMEWORKS_DIR/"
    chmod -R 755 "$FRAMEWORKS_DIR" 2>/dev/null || true
fi

if [ -d "$FRAMEWORKS_DIR" ] && [ "$(find "$FRAMEWORKS_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" -gt 0 ]; then
    if ! otool -l "$EXECUTABLE_PATH" | grep -q "@executable_path/../Frameworks"; then
        install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE_PATH" 2>/dev/null || true
    fi
fi

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --remove-signature "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "Ad-hoc codesign skipped."

echo
echo "Created app:"
echo "$APP_DIR"
