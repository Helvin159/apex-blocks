# Release notes: ads

## Test ads by default
Every build (debug, profile, release, TestFlight) uses Google's official **test** ad unit IDs. Real unit IDs are used only with:

```
flutter build ipa --dart-define=REAL_ADS=true
```

`lib/config/ad_config.dart` holds every ID. Fill in the `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX` placeholders first: with `REAL_ADS=true` and a placeholder left, ads stay off and an error is logged, so a junk ID is never requested. The app logs the active mode (`TEST ads` / `REAL ads`) at startup in debug.

Three separate units are needed per platform, so AdMob reports each one separately:
rewarded **Pit Stop**, rewarded **livery unlock**, interstitial **between races**.

## Real IDs stay out of git
Nothing real is committed. Three git-ignored files hold the IDs; each has a committed `*.example` template:

| File | Holds | Template |
| --- | --- | --- |
| `ad_ids.json` | the 6 ad unit IDs (3 per platform) | `ad_ids.example.json` |
| `ios/Flutter/AdMob.xcconfig` | iOS AdMob app ID (`ADMOB_APP_ID`) | `AdMob.example.xcconfig` |
| `android/admob.properties` | Android AdMob app ID (`appId`) | `admob.example.properties` |

Without the app-ID files the native app IDs fall back to Google's **test** app IDs (`AdMobDefaults.xcconfig`, `build.gradle.kts`).

Build with real ads:

```
flutter build ipa --dart-define=REAL_ADS=true --dart-define-from-file=ad_ids.json
```

Never mix: real unit IDs need the real app ID of the same app, and test units need the test app ID. (These IDs ship inside the app binary, so gitignoring only keeps them out of the repo.) Before any release build, check that `git status` shows none of the three files.

## iOS
- `NSUserTrackingUsageDescription` is set. The ATT prompt is shown by Google's UMP message once the IDFA explainer message is configured in AdMob (Privacy & messaging).
- `SKAdNetworkItems` holds the 50 identifiers from the example on https://developers.google.com/admob/ios/quick-start. Google also keeps a longer third-party list (https://developers.google.com/admob/ios/3p-skadnetworks); refresh both before release.

## Android
- The Google Mobile Ads SDK adds the `com.google.android.gms.permission.AD_ID` permission through manifest merge. Declare advertising ID use in the Play Console **Data safety** form and the App content > Advertising ID declaration.

# Release notes: Remove Ads purchase

Product ID `remove_ads` (non-consumable), defined once in `lib/config/ad_config.dart` as `removeAdsProductId`. The price is never in the app: it comes from the store at runtime, so it follows the price set in App Store Connect.

## Set up before testing
- **iOS:** App Store Connect > the app > Monetization > In-App Purchases: create a **Non-Consumable** with Product ID `remove_ads`, a reference name, a price and a localized display name/description, plus the review screenshot. It must be Ready to Submit, and the Paid Apps agreement, tax and banking must be done, or the app only ever shows "Unavailable right now". Add a **Sandbox Apple Account** (Users and Access > Sandbox) for TestFlight purchases (sandbox purchases are free).
- **Android (later):** create an in-app product with the same ID `remove_ads` in Play Console after the app is uploaded to a test track. No code change is needed.

## Behavior
- The purchase stream is subscribed at startup (before any UI), so purchases finished while the app was closed are granted. Every update with `pendingCompletePurchase` is completed, whatever its status.
- Remove Ads turns off interstitials (none is even loaded) and unlocks every livery. Rewarded ads stay, only when tapped.
- Restore Purchases is on the CLEAN AIR sheet and in Setup.
- Debug builds only: Setup has "Debug: reset purchase" (clears the local flag; the store still owns it, so Restore brings it back) and "Debug: reset all progress".
- To buy again with the same sandbox account, clear its purchase history in App Store Connect (Sandbox Apple Account > Clear Purchase History).
