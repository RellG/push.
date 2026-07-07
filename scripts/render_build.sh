#!/usr/bin/env bash
# Render static-site build: installs Flutter, patches the pub cache, builds web.
set -euo pipefail

FLUTTER_VERSION="3.44.5"
SDK_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/flutter-sdk"
FLUTTER_HOME="$SDK_ROOT/flutter"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Downloading Flutter $FLUTTER_VERSION..."
  rm -rf "$SDK_ROOT"
  mkdir -p "$SDK_ROOT"
  curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar xJ -C "$SDK_ROOT"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter --version

flutter pub get
python3 scripts/patch_lucide_icons.py
flutter build web --release

echo "Web build complete: build/web"
