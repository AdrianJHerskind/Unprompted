#!/bin/bash
# Builds Unprompted.app, installs it in /Applications and (re)starts it.
#
#   ./build.sh                 release build, install, restart
#   ./build.sh debug           debug build, install, restart
#   ./build.sh --no-install    only build into build/
set -euo pipefail
cd "$(dirname "$0")"

CONFIG=release
INSTALL=1
for arg in "$@"; do
    case "$arg" in
        debug|release) CONFIG="$arg" ;;
        --no-install) INSTALL=0 ;;
        *) echo "Usage: $0 [debug|release] [--no-install]" >&2; exit 1 ;;
    esac
done

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Unprompted"

APP=build/Unprompted.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/Characters "$APP/Contents/Resources/"
codesign --force --sign - "$APP" >/dev/null 2>&1
echo "Built $APP"

if [ "$INSTALL" = 1 ]; then
    # Quit any running copy so the new one takes over.
    if pkill -x Unprompted; then sleep 0.5; fi
    rm -rf /Applications/Unprompted.app
    cp -R "$APP" /Applications/
    touch /Applications/Unprompted.app # nudge Finder to pick up icon changes
    open /Applications/Unprompted.app
    echo "Installed and started /Applications/Unprompted.app"
fi
