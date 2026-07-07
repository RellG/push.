#!/usr/bin/env python3
"""Patch the cached lucide_icons 0.257.0 package for Flutter 3.27+.

lucide_icons 0.257.0 predates Flutter making IconData a `final class`, so its
`class LucideIconData extends IconData` no longer compiles. This applies the
pub-cache patch documented in README "Current Notes" so clean machines and CI
builders (e.g. Render) can build without manual edits. Safe to re-run.
"""

import os
import re
import sys

PACKAGE = os.path.expanduser(
    os.environ.get("PUB_CACHE", "~/.pub-cache") + "/hosted/pub.dev/lucide_icons-0.257.0"
)


def main() -> int:
    if not os.path.isdir(PACKAGE):
        print(f"lucide_icons cache not found at {PACKAGE} — run `flutter pub get` first")
        return 1

    pubspec = os.path.join(PACKAGE, "pubspec.yaml")
    with open(pubspec) as f:
        text = f.read()
    text = re.sub(
        r"^environment:\n  sdk: .*$",
        'environment:\n  sdk: ">=3.3.0 <4.0.0"',
        text,
        flags=re.MULTILINE,
    )
    with open(pubspec, "w") as f:
        f.write(text)

    icons = os.path.join(PACKAGE, "lib", "lucide_icons.dart")
    with open(icons) as f:
        text = f.read()
    text = re.sub(
        r"const LucideIconData\((0x[0-9a-fA-F]+)\)",
        r"IconData(\1, fontFamily: 'Lucide', fontPackage: 'lucide_icons')",
        text,
    )
    with open(icons, "w") as f:
        f.write(text)

    with open(os.path.join(PACKAGE, "lib", "src", "icon_data.dart"), "w") as f:
        f.write(
            "import 'package:flutter/widgets.dart';\n\n"
            "typedef LucideIconData = IconData;\n"
        )

    print("lucide_icons 0.257.0 patched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
