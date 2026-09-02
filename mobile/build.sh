#!/bin/bash
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi
export PATH="$PATH:`pwd`/flutter/bin"
if [ -n "$API_BASE_URL" ]; then
  flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
else
  flutter build web --release
fi
