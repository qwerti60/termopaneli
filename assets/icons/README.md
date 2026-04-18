Place icon files here:

- `assets/icons/app_icon.png` - base icon for iOS and fallback.
- `assets/icons/app_icon_foreground.png` - foreground layer for Android adaptive icon.

Recommended format:

- PNG, 1024x1024, square.
- For `app_icon_foreground.png`, keep transparent background and logo centered.

Current Android adaptive icon background color:

- `#E3E3E3`

Generate icons:

1. `flutter pub get`
2. `flutter pub run flutter_launcher_icons`
