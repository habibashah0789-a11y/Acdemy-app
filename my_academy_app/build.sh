#!/bin/bash
set -e

echo "=========================================="
echo " Starting Quaid Academy Vercel Web Build  "
echo "=========================================="

# 1. Clone Flutter SDK if not cached
if [ ! -d "flutter" ]; then
  echo "--> Cloning Flutter SDK (stable channel)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "--> Flutter SDK already exists. Updating..."
  cd flutter && git pull && cd ..
fi

# 2. Setup PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Disable telemetry & print version
flutter config --no-analytics
flutter --version

# 4. Get pub dependencies
echo "--> Installing dependencies via pub get..."
flutter pub get

# 5. Build Web Release
echo "--> Building Flutter Web Release..."
flutter build web --release

echo "=========================================="
echo " Flutter Web Build Completed Successfully! "
echo "=========================================="
