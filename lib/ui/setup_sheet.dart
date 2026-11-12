import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/ad_config.dart';
import '../config/links.dart';
import '../services/audio_service.dart';
import '../services/consent_service.dart';
import '../services/haptics_service.dart';
import '../services/iap_service.dart';
import '../services/storage_service.dart';
import '../theme/themes.dart';
import 'purchase_text.dart';

/// Keep in sync with `version:` in pubspec.yaml (no package_info_plus).
const String appVersion = '1.0.0+7';

const String _appName = 'Apex Blocks';

/// Opens [url] outside the app. Returns false if nothing could open it.
typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> _openInBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Applies the saved sound and haptics toggles to the services.
void applySavedSettings(
  StorageService storage,
  AudioService audio,
  HapticsService haptics,
) {
  audio.enabled.value = storage.soundOn;
  haptics.enabled.value = storage.hapticsOn;
}

/// Opens the Setup sheet: Sound and Haptics toggles, privacy and support
/// links, Restore Purchases, Licenses, version (and reset rows in debug
/// builds).
Future<void> showSetupSheet(
  BuildContext context, {
  required StorageService storage,
  required AudioService audio,
  required HapticsService haptics,
  ConsentService? consent,
  IapService? iap,
  UrlOpener openUrl = _openInBrowser,
}) {
  final theme = storage.theme;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SetupSheet(
      storage: storage,
      audio: audio,
      haptics: haptics,
      consent: consent,
      iap: iap,
      openUrl: openUrl,
    ),
  );
}

class SetupSheet extends StatefulWidget {
  final StorageService storage;
  final AudioService audio;
  final HapticsService haptics;

  /// Source of the "Privacy choices" row; the row is absent when null.
  final ConsentService? consent;

  /// Source of the "Restore Purchases" row; the row is absent when null.
  final IapService? iap;

  /// Opens the privacy policy and support pages.
  final UrlOpener openUrl;

  /// Shows the debug-only reset rows. Release builds never do.
  final bool showDebugTools;

  /// True when this build serves real ads; otherwise the Version row says so.
  final bool realAds;

  const SetupSheet({
    super.key,
    required this.storage,
    required this.audio,
    required this.haptics,
    this.consent,
    this.iap,
    this.openUrl = _openInBrowser,
    this.showDebugTools = kDebugMode,
    this.realAds = realAdsRequested,
  });

  @override
  State<SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<SetupSheet> {
  /// Result of the last Restore Purchases attempt.
  String? _restoreMessage;

  /// Set when a page could not be opened, so its address can be copied.
  String? _failedUrl;

  StorageService get storage => widget.storage;
  AudioService get audio => widget.audio;
  HapticsService get haptics => widget.haptics;
  ConsentService? get consent => widget.consent;

  Future<void> _restore(IapService iap) async {
    setState(() => _restoreMessage = null);
    final outcome = await iap.restore();
    if (mounted) setState(() => _restoreMessage = restoreText(outcome));
  }

  Future<void> _open(String url) async {
    setState(() => _failedUrl = null);
    var opened = false;
    try {
      opened = await widget.openUrl(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) setState(() => _failedUrl = url);
  }

  Widget _linkRow(ApexTheme theme, String title, String url) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 48,
    title: Text(title, style: _rowStyle(theme)),
    subtitle: _failedUrl == url
        ? SelectableText(url, style: _noteStyle(theme))
        : null,
    trailing: Icon(Icons.open_in_new, color: theme.muted, size: 20),
    onTap: () => _open(url),
  );

  @override
  Widget build(BuildContext context) {
    final iap = widget.iap;
    return ListenableBuilder(
      listenable: Listenable.merge([storage, ?iap]),
      builder: (context, _) {
        final theme = storage.theme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SETUP',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      fontSize: 28,
                      color: theme.text,
                    ),
                  ),
                ),
                _ToggleRow(
                  theme: theme,
                  label: 'Sound',
                  value: storage.soundOn,
                  onChanged: (v) {
                    audio.enabled.value = v;
                    storage.setSoundOn(v);
                  },
                ),
                _ToggleRow(
                  theme: theme,
                  label: 'Haptics',
                  value: storage.hapticsOn,
                  onChanged: (v) {
                    haptics.enabled.value = v;
                    storage.setHapticsOn(v);
                  },
                ),
                if (consent != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: consent!.privacyOptionsRequired,
                    builder: (context, required, _) => required
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            minTileHeight: 48,
                            title: Text(
                              'Privacy choices',
                              style: _rowStyle(theme),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: theme.muted,
                            ),
                            onTap: consent!.showPrivacyOptions,
                          )
                        : const SizedBox.shrink(),
                  ),
                _linkRow(theme, 'Privacy policy', privacyPolicyUrl),
                _linkRow(theme, 'Help & support', supportUrl),
                if (iap != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 48,
                    title: Text('Restore Purchases', style: _rowStyle(theme)),
                    subtitle: iap.restoring
                        ? Text('Restoring…', style: _noteStyle(theme))
                        : _restoreMessage == null
                        ? null
                        : Text(_restoreMessage!, style: _noteStyle(theme)),
                    trailing: Icon(Icons.chevron_right, color: theme.muted),
                    onTap: iap.restoring ? null : () => _restore(iap),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 48,
                  title: Text('Licenses', style: _rowStyle(theme)),
                  trailing: Icon(Icons.chevron_right, color: theme.muted),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: _appName,
                    applicationVersion: appVersion,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 48,
                  title: Text('Version', style: _rowStyle(theme)),
                  // A correct App Store build is in real-ads mode and shows
                  // no note, so a leftover test build is easy to spot.
                  subtitle: widget.realAds
                      ? null
                      : Text('Test ads', style: _noteStyle(theme)),
                  trailing: Text(
                    appVersion,
                    style: _rowStyle(theme).copyWith(color: theme.muted),
                  ),
                ),
                // Debug builds only; compiled out of release builds.
                if (widget.showDebugTools) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 48,
                    title: Text(
                      'Debug: reset purchase',
                      style: _rowStyle(theme),
                    ),
                    onTap: storage.debugResetPurchase,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 48,
                    title: Text(
                      'Debug: reset all progress',
                      style: _rowStyle(theme),
                    ),
                    onTap: storage.debugResetAllProgress,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

TextStyle _rowStyle(ApexTheme theme) => TextStyle(
  fontFamily: 'Inter',
  fontVariations: const [FontVariation('wght', 500)],
  fontSize: 16,
  color: theme.text,
);

TextStyle _noteStyle(ApexTheme theme) => TextStyle(
  fontFamily: 'Inter',
  fontVariations: const [FontVariation('wght', 500)],
  fontSize: 13,
  color: theme.muted,
);

class _ToggleRow extends StatelessWidget {
  final ApexTheme theme;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.theme,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: _rowStyle(theme)),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: theme.accent,
      onChanged: onChanged,
    );
  }
}
