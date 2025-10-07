import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows default BPM (160) on startup', (tester) async {
    await tester.pumpWidget(const CadenceApp());
    await tester.pumpAndSettle();
    expect(find.text('160'), findsOneWidget);
  });

  testWidgets('slider changes update displayed BPM', (tester) async {
    await tester.pumpWidget(const CadenceApp());
    await tester.pumpAndSettle();

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);

    // Drag the slider to the right to increase BPM (simple heuristic).
    await tester.drag(slider, const Offset(150, 0));
    await tester.pumpAndSettle();

    // Expect the displayed BPM to have changed (should be > 160).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            int.tryParse(w.data ?? '') != null &&
            int.parse(w.data!) > 160,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Start button starts and toggles to Stop, then back to Start',
      (tester) async {
    await tester.pumpWidget(const CadenceApp());
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('tapping theme toggle switches between light and dark',
      (tester) async {
    await tester.pumpWidget(const CadenceApp());
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);

    final toggle = find.byTooltip('Toggle theme');
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets(
      'tapping theme toggle switches between light and dark when system is dark',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    await tester.pumpWidget(const CadenceApp());
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);

    final toggle = find.byTooltip('Toggle theme');
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  testWidgets('BPM text remains unchanged during tick',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CadenceApp());

    // Find the BPM text
    final bpmFinder = find.text('160');
    expect(bpmFinder, findsOneWidget);

    // Tap the Start button by its label text
    final startText = find.text('Start');
    expect(startText, findsOneWidget);
    await tester.tap(startText);
    await tester.pump();

    // Advance time by ~500ms to allow the periodic timer tick (60000/160 ~= 375ms)
    await tester.pump(const Duration(milliseconds: 500));

    // The text should remain the same (still shows 160)
    expect(find.text('160'), findsOneWidget);
  });
}
