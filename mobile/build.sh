#!/bin/bash
# Pinned to an exact tag rather than "-b stable": stable is a moving branch,
# so an unpinned clone picks up whatever Flutter happens to be newest at
# build time. That silently broke this build once already - a newer stable
# release made Flutter's IconData class `final`, which phosphor_flutter
# 2.1.0's PhosphorIconData (extends IconData) can no longer compile against.
# 3.41.7 is confirmed working with the app's current dependencies; bump this
# deliberately (and re-verify the build) rather than letting it drift.
FLUTTER_VERSION="3.41.7"
# Re-clone if a cached flutter/ dir from a prior build is checked out at a
# different version - Vercel's build cache can persist this directory across
# deployments, which would otherwise silently defeat the pin above.
if [ -d "flutter" ] && [ "$(git -C flutter describe --tags 2>/dev/null)" != "$FLUTTER_VERSION" ]; then
  rm -rf flutter
fi
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1
fi
export PATH="$PATH:`pwd`/flutter/bin"
flutter build web --release
