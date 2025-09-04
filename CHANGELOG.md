# Changelog

## [0.1.0] – 2025-09-04
### Added
- GitHub Actions: Flutter CI (`.github/workflows/flutter-ci.yml`)

### Changed
- Onboarding: **Profile-Completion-Gate** (erzwingt Profilvervollständigung nach Registrierung/Login)
- Registrierungsflow: Bestätigungsseite mit Hinweis + Button „Profil jetzt ergänzen“
- Navigation: `/public`-Route für öffentliche Landing, `AuthGate` als `home`

### Fixed
- Login-/Registrierungshänger (White Screen) durch saubere Weiterleitungen
- Firebase-Projektkonfiguration (android/ios/web) mit `flutterfire configure`
