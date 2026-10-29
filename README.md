# StrongBody Buyer

Flutter app cho buyer của StrongBody. Kiến trúc mirror theo `../Multime_Version_2` (xem `CLAUDE.md`).

## Lệnh

```bash
flutter pub get

# Chạy (1 entry, flavor dev/prod cho cả Android lẫn iOS — bắt buộc --flavor)
flutter run -t lib/main.dart --flavor dev
flutter run -t lib/main.dart --flavor prod

# Build
flutter build apk --release --flavor prod -t lib/main.dart
flutter build ipa --release --flavor prod -t lib/main.dart

# Sinh LocaleKeys sau khi sửa assets/translations (bắt buộc -s en.json)
dart run easy_localization:generate -S assets/translations -s en.json -O lib/core/l10n -o locale_keys.g.dart -f keys

flutter analyze
flutter test
```
