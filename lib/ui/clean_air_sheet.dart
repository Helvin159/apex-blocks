import 'package:flutter/material.dart';

import '../services/iap_service.dart';
import '../services/storage_service.dart';
import '../theme/themes.dart';
import 'purchase_text.dart';

const List<String> _bullets = [
  'No more ads between races',
  'Unlocks every livery',
  'Optional reward ads stay available, only if you tap them',
];

/// Opens the CLEAN AIR sheet: what Remove Ads gives, the buy button with the
/// store's price, and Restore purchase.
Future<void> showCleanAirSheet(
  BuildContext context, {
  required StorageService storage,
  required IapService iap,
}) {
  iap.clearNotice();
  // Offline earlier, or not loaded yet: try again now.
  if (iap.productState == ProductState.unavailable) iap.loadProduct();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: storage.theme.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => CleanAirSheet(storage: storage, iap: iap),
  );
}

class CleanAirSheet extends StatefulWidget {
  final StorageService storage;
  final IapService iap;

  const CleanAirSheet({super.key, required this.storage, required this.iap});

  @override
  State<CleanAirSheet> createState() => _CleanAirSheetState();
}

class _CleanAirSheetState extends State<CleanAirSheet> {
  String? _restoreMessage;

  Future<void> _restore() async {
    setState(() => _restoreMessage = null);
    final outcome = await widget.iap.restore();
    if (mounted) setState(() => _restoreMessage = restoreText(outcome));
  }

  String _buyLabel(IapService iap) {
    if (iap.purchasing) return 'Processing…';
    return switch (iap.productState) {
      ProductState.available => 'Remove ads · ${iap.price}',
      ProductState.loading => 'Loading price…',
      ProductState.unavailable => 'Unavailable right now',
    };
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.storage;
    final iap = widget.iap;
    return ListenableBuilder(
      listenable: Listenable.merge([storage, iap]),
      builder: (context, _) {
        final theme = storage.theme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLEAN AIR',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    fontSize: 28,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 8),
                for (final bullet in _bullets)
                  _Bullet(theme: theme, text: bullet),
                const SizedBox(height: 16),
                if (storage.adsRemoved)
                  ..._active(context, theme)
                else
                  ..._buy(theme, iap),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _active(BuildContext context, ApexTheme theme) => [
    Text(
      'Thank you! CLEAN AIR is active.',
      style: _bodyStyle(theme.highlight, 15),
    ),
    const SizedBox(height: 12),
    _SheetButton(
      theme: theme,
      label: 'DONE',
      onPressed: () => Navigator.pop(context),
    ),
  ];

  List<Widget> _buy(ApexTheme theme, IapService iap) {
    final canBuy =
        iap.productState == ProductState.available && !iap.purchasing;
    final notice = iap.notice;
    return [
      _SheetButton(
        theme: theme,
        label: _buyLabel(iap),
        onPressed: canBuy ? iap.buy : null,
      ),
      if (notice != null) ...[
        const SizedBox(height: 8),
        Text(noticeText(notice), style: _bodyStyle(theme.muted, 13)),
      ],
      const SizedBox(height: 4),
      Center(
        child: SizedBox(
          height: 44,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: theme.muted),
            onPressed: iap.restoring || iap.purchasing ? null : _restore,
            child: Text(
              iap.restoring ? 'Restoring…' : 'Restore purchase',
              style: _bodyStyle(theme.muted, 14),
            ),
          ),
        ),
      ),
      if (_restoreMessage != null)
        Center(
          child: Text(_restoreMessage!, style: _bodyStyle(theme.muted, 13)),
        ),
    ];
  }
}

TextStyle _bodyStyle(Color color, double size) => TextStyle(
  fontFamily: 'Inter',
  fontVariations: const [FontVariation('wght', 500)],
  fontSize: size,
  color: color,
);

class _Bullet extends StatelessWidget {
  final ApexTheme theme;
  final String text;

  const _Bullet({required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: _bodyStyle(theme.text, 15))),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final ApexTheme theme;
  final String label;
  final VoidCallback? onPressed;

  const _SheetButton({
    required this.theme,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.panelAlt,
          disabledForegroundColor: theme.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: 22,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
