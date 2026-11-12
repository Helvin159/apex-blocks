# Apex Blocks

An endless block puzzle for iOS and Android with a night-race look. One home
screen, one game screen, no levels.

- The spec and working rules are in [CLAUDE.md](CLAUDE.md).
- Release and App Store steps are in [RELEASE.md](RELEASE.md).
- Third-party assets and licenses are in [ASSETS.md](ASSETS.md).

## Develop

```
flutter pub get
flutter analyze
flutter test
flutter run            # debug build, Google test ads
flutter run --profile  # to check frame times on a real phone
```

`lib/game/` is pure Dart (no Flutter imports) and fully unit-tested.
