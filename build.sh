#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

mkdir -p bin

echo "=> Compiling aqw-haxe-ui (ModUI.swc)..."
if command -v haxe >/dev/null 2>&1; then
    haxe build.hxml
else
    npx haxe build.hxml
fi

if [ -d "$DIR/../aqw-mobile-mod/loader/libs" ]; then
    cp "$DIR/bin/ModUI.swc" "$DIR/../aqw-mobile-mod/loader/libs/ModUI.swc"
    echo "=> Copied ModUI.swc to aqw-mobile-mod/loader/libs/"
fi

echo "=> aqw-haxe-ui built successfully: bin/ModUI.swc"

