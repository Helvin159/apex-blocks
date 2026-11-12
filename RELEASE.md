# Release notes: ads

## Test ads by default
Every build (debug, profile, release, TestFlight) uses Google's official **test** ad unit IDs. Real unit IDs are used only with:

```
flutter build ipa --dart-define=REAL_ADS=true
```

`lib/config/ad_config.dart` holds every ID. Fill in the `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX` placeholders first: with `REAL_ADS=true` and a placeholder left, ads stay off and an error is logged, so a junk ID is never requested. The app logs the active mode (`Ads: TEST ads` / `Ads: REAL ads`) at startup in every build mode, and Setup > Version shows a "Test ads" note in any build that is not in real-ads mode.

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
- Debug builds only (never release; see "Debug tools" below): Setup has "Debug: reset purchase" (clears the local flag; the store still owns it, so Restore brings it back) and "Debug: reset all progress".
- To buy again with the same sandbox account, clear its purchase history in App Store Connect (Sandbox Apple Account > Clear Purchase History).

# App Store submission

Work through this top to bottom for every upload. Version now: **1.0.0+7**.

## 1. Real ads (one-time setup, then per build)
1. `cp ad_ids.example.json ad_ids.json` and fill in the six real ad unit IDs (3 per platform: Pit Stop, livery unlock, interstitial). Only the three `IOS_*` values matter for the iOS upload.
2. `cp ios/Flutter/AdMob.example.xcconfig ios/Flutter/AdMob.xcconfig` and set `ADMOB_APP_ID` to the **real iOS AdMob app ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`). This is what switches `GADApplicationIdentifier` in `Info.plist` (`$(ADMOB_APP_ID)`) away from Google's test app ID. Real unit IDs with the test app ID, or the reverse, will not serve properly.
3. Both files are git-ignored. Run `git status` and confirm neither shows up.

## 2. Bump the build number
Every upload to App Store Connect needs a build number that was never used before.
1. In `pubspec.yaml` change `version: 1.0.0+7` to the next `+N` (and the first part for a new release).
2. Make the same change to `appVersion` in `lib/ui/setup_sheet.dart`. `test/ui/setup_sheet_test.dart` fails if the two differ.

## 3. Checks before building
```
flutter analyze
flutter test
```

## 4. Build
```
flutter build ipa --release --dart-define=REAL_ADS=true --dart-define-from-file=ad_ids.json
```
Then upload `build/ios/ipa/*.ipa` with Xcode's Organizer or Transporter.

## 5. Confirm the build is in REAL ads mode
A build without `REAL_ADS=true` quietly uses Google's test ads and would ship with no revenue. Check on a real device with the exact build (TestFlight or the .ipa):
- **Setup sheet > Version row:** a build in real-ads mode shows **no** "Test ads" note under the version number. If "Test ads" appears, do not submit.
- **Startup log:** plug in the device, open Xcode > Window > Devices and Simulators > Open Console (or Console.app, select the device) and launch the app. The log must contain `Ads: REAL ads`. `Ads: TEST ads` means the flag was missed. `Ads: real IDs are still placeholders, ads stay off` means `ad_ids.json` was not passed or is incomplete.
- Do not tap real ads on your own device. Use a test device registered in AdMob if you need to look at one.

## 6. Privacy and App Store Connect
- **Privacy policy / support pages** are live: https://helvin159.github.io/apex-blocks/privacy.html and https://helvin159.github.io/apex-blocks/support.html (the Setup sheet opens them). Put the privacy URL in App Store Connect too.
- **App Privacy answers** must match the SDKs. The Google Mobile Ads SDK's bundled manifest declares: Device ID (linked, used for tracking), Advertising Data, Product Interaction, Coarse Location (all linked), Performance Data, Other Diagnostic Data, Crash Data (not linked), for third-party advertising, developer advertising and analytics. Answer the App Privacy questionnaire consistently with that and with the app's own `ios/Runner/PrivacyInfo.xcprivacy`.
- **Tracking domains:** the app manifest declares `NSPrivacyTracking = true` and an empty `NSPrivacyTrackingDomains`. Google does not publish a list that could be copied in, so none is declared. If Apple's review or Google's AdMob guidance later asks for them, add them there.
- **App Tracking Transparency / consent:** the AdMob Privacy & messaging page needs the GDPR message and the IDFA explainer message published, or the consent flow and ATT prompt never show.
- **Remove Ads:** the `remove_ads` non-consumable is in Ready to Submit and attached to this version, with a review screenshot (see "Remove Ads purchase" above). Paid Apps agreement, tax and banking done.
- **Export compliance:** `ITSAppUsesNonExemptEncryption` is `false` in `Info.plist`, so there is no question at upload.
- **Trademark:** the USPTO search for "Apex Blocks" is still pending (CLAUDE.md). Finish it before submitting.
- **Listing text:** motorsport vibe only. No "Formula 1", "F1", "Grand Prix", team, driver, circuit or tyre-brand names, and no official logos or liveries.

## Privacy manifest
`ios/Runner/PrivacyInfo.xcprivacy` is the app's own manifest. It declares tracking (because the ad SDK uses the advertising ID after ATT consent), no tracking domains, no collected data types of its own, and no required-reason API use by the app's own code. The plugins and SDKs ship their own manifests (shared_preferences, in_app_purchase, url_launcher, Google Mobile Ads, User Messaging Platform), which Xcode merges into the archive's privacy report. After archiving, Xcode > Organizer > the archive > Generate Privacy Report shows the combined result.

## Debug tools
The Setup reset rows, the Pole-card long-press and the `debug*` storage methods exist only under `kDebugMode`, so they are compiled out of release builds. `test/ui/setup_sheet_test.dart` checks the gating. To double check a release build: `flutter build apk --release`, then `unzip -o -q build/app/outputs/flutter-apk/app-release.apk 'lib/*' -d /tmp/apk-check && strings /tmp/apk-check/lib/arm64-v8a/libapp.so | grep -c "Debug: reset"` must print `0` (while `grep -c "Privacy policy"` prints `1`, proving the check is looking at the right file).

## Drop effects
Every per-placement effect has a switch (`dropFx*`) at the top of `lib/ui/effects/drop_effects.dart`. If one hurts frame times on an older phone, set it to `false`. Check frame times with `flutter run --profile` and the performance overlay.
