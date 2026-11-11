import 'package:apexblocks/theme/themes.dart';
import 'package:apexblocks/ui/combo_popup.dart';
import 'package:apexblocks/ui/popup_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.byType(Opacity)).opacity;

void main() {
  testWidgets('pops in, holds, fades and re-triggers', (tester) async {
    final event = ValueNotifier<PopupEvent?>(null);
    await tester.pumpWidget(
      MaterialApp(
        home: ComboPopup(event: event, theme: nightRace),
      ),
    );
    expect(find.byType(Text), findsNothing);

    const text = PopupText(headline: 'OVERTAKE!', detail: 'COMBO ×2 · +30');
    event.value = const PopupEvent(1, text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: popupInMs));
    expect(find.text('OVERTAKE!'), findsOneWidget);
    expect(find.text('COMBO ×2 · +30'), findsOneWidget);
    expect(opacity(tester), 1);

    await tester.pump(const Duration(milliseconds: popupHoldMs ~/ 2));
    expect(opacity(tester), 1);

    await tester.pump(const Duration(milliseconds: popupFadeMs + popupHoldMs));
    expect(opacity(tester), 0);

    // Same text, new id: shows again.
    event.value = const PopupEvent(2, text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: popupInMs));
    expect(opacity(tester), 1);
    await tester.pumpAndSettle();
  });
}
