import 'package:flutter/material.dart';

import '../game/unlocks.dart';
import '../services/ad_rules.dart';
import '../services/ads_service.dart';
import '../services/storage_service.dart';
import '../theme/themes.dart';
import 'game_over_screen.dart';

String _withCommas(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Explains how to unlock a locked [livery] and offers the rewarded-ad route.
Future<void> showLiverySheet(
  BuildContext context, {
  required StorageService storage,
  required AdsService ads,
  required int livery,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: storage.theme.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => LiverySheet(storage: storage, ads: ads, livery: livery),
  );
}

class LiverySheet extends StatefulWidget {
  final StorageService storage;
  final AdsService ads;
  final int livery;

  const LiverySheet({
    super.key,
    required this.storage,
    required this.ads,
    required this.livery,
  });

  @override
  State<LiverySheet> createState() => _LiverySheetState();
}

class _LiverySheetState extends State<LiverySheet> {
  bool _busy = false;

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    // The reward is granted only when the ad reports it was earned.
    final earned = await widget.ads.showRewarded(
      RewardedPlacement.liveryUnlock,
    );
    if (earned) await widget.storage.recordLiveryAdWatched(widget.livery);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.storage, widget.ads]),
      builder: (context, _) {
        final storage = widget.storage;
        final theme = storage.theme;
        final livery = allLiveries[widget.livery];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (storage.isLiveryUnlockedNow(widget.livery))
                  LiveryUnlockedBanner(
                    theme: theme,
                    name: livery.name,
                    equipped: storage.selectedLivery == widget.livery,
                    onEquip: () async {
                      await storage.selectLivery(widget.livery);
                      if (context.mounted) Navigator.pop(context);
                    },
                  )
                else
                  ..._locked(theme, livery),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _locked(ApexTheme theme, ApexTheme livery) {
    final storage = widget.storage;
    final ads = widget.ads;
    final watched = storage.liveryAdsWatched(widget.livery);
    final career = storage.careerPoints;
    final target = liveryUnlockPoints[widget.livery];
    final offerAds = ads.isRewardedAvailable(RewardedPlacement.liveryUnlock);
    final ready = ads.isRewardedReady(RewardedPlacement.liveryUnlock);
    return [
      Text(
        livery.name.toUpperCase(),
        style: TextStyle(
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          fontSize: 28,
          color: theme.text,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Locked. Earn ${_withCommas(target)} career points '
        '(${_withCommas(career)} so far)'
        '${offerAds ? ', or watch $liveryAdsRequired ads.' : '.'}',
        style: TextStyle(
          fontFamily: 'Inter',
          fontVariations: const [FontVariation('wght', 500)],
          fontSize: 14,
          color: theme.muted,
        ),
      ),
      if (offerAds) ...[
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: ready && !_busy ? _watch : null,
            child: Text(
              ready
                  ? 'Watch ad (${watched + 1}/$liveryAdsRequired)'
                  : 'Loading ad…',
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                fontSize: 22,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    ];
  }
}
