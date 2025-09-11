#!/bin/zsh
set -e

echo "🚀 Baue Flutter Web (PROD)…"
flutter clean
flutter pub get
flutter build web --release --dart-define=FLAVOR=prod

echo "🚀 Deploye zu Firebase Hosting (PROD)…"
firebase deploy --only hosting --project sponsorenlauf-evp-wetzikon