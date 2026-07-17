import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/widgets/mini_player.dart';
import 'package:flutter_application_1/widgets/spectrum_visualizer.dart';

void main() {
  Future<void> pumpAuralis(WidgetTester tester) async {
    await tester.pumpWidget(const AuralisApp(useDemoLibrary: true));
    await tester.pumpAndSettle();
    final skip = find.text('Set up later');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Auralis launches and exposes core navigation', (tester) async {
    await pumpAuralis(tester);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Good ') ?? false),
      ),
      findsOneWidget,
    );
    expect(find.text('Glass Horizon'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('mini player toggles playback and opens now playing', (
    tester,
  ) async {
    await pumpAuralis(tester);

    final miniPlay = find.descendant(
      of: find.byType(MiniPlayer),
      matching: find.byTooltip('Play'),
    );
    await tester.tap(miniPlay);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byTooltip('Pause'),
      ),
      findsOneWidget,
    );
    expect(find.byType(SpectrumVisualizer), findsOneWidget);

    await tester.tap(find.byType(MiniPlayer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('NOW PLAYING'), findsOneWidget);
    expect(find.byTooltip('Close now playing'), findsOneWidget);
    expect(find.byType(SpectrumVisualizer), findsWidgets);
  });

  testWidgets('search filters the local library', (tester) async {
    await pumpAuralis(tester);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Northline');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 results'), findsOneWidget);
    expect(find.text('Open Water'), findsOneWidget);
    expect(find.text('Low Tide'), findsOneWidget);
  });
}
