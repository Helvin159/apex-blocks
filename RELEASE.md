# Release notes: ads

## Test ads by default
Every build (debug, profile, release, TestFlight) uses Google's official **test** ad unit IDs. Real unit IDs are used only with:

```
flutter build ipa --dart-define=REAL_ADS=true
```

`lib/config/ad_config.dart` holds every ID. Fill in the `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX` placeholders first: with `REAL_ADS=true` and a placeholder left, ads stay off and an error is logged, so a junk ID is never requested. The app logs the active mode (`TEST ads` / `REAL ads`) at startup in debug.

Three separate units are needed per platform, so AdMob reports each one separately:
rewarded **Pit Stop**, rewarded **livery unlock**, interstitial **between races**.

## Switching the native app IDs for the App Store / Play build
The native app IDs cannot be set with `--dart-define`; they are Google's **test** app IDs for now.

1. iOS: `ios/Runner/Info.plist`, key `GADApplicationIdentifier` (currently `ca-app-pub-3940256099942544~1458002511`). Replace with the real iOS app ID (`ca-app-pub-<publisher>~<app>`).
2. Android: `android/app/src/main/AndroidManifest.xml`, meta-data `com.google.android.gms.ads.APPLICATION_ID` (currently `ca-app-pub-3940256099942544~3347511713`). Replace with the real Android app ID.
3. Replace the unit ID placeholders in `lib/config/ad_config.dart`.
4. Build with `--dart-define=REAL_ADS=true`.

Never mix them: real unit IDs with a test app ID (or the reverse) will not serve properly.

## iOS
- `NSUserTrackingUsageDescription` is set. The ATT prompt is shown by Google's UMP message once the IDFA explainer message is configured in AdMob (Privacy & messaging).
- `SKAdNetworkItems` holds the 50 identifiers from the example on https://developers.google.com/admob/ios/quick-start. Google also keeps a longer third-party list (https://developers.google.com/admob/ios/3p-skadnetworks); refresh both before release.

## Android
- The Google Mobile Ads SDK adds the `com.google.android.gms.permission.AD_ID` permission through manifest merge. Declare advertising ID use in the Play Console **Data safety** form and the App content > Advertising ID declaration.
