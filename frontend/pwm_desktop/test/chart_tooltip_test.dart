import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/dashboard_data.dart';
import 'package:pwm_desktop/screens/widgets/hours_by_project_chart.dart';
import 'package:pwm_desktop/utils/app_theme.dart';

/// The tooltip is painted onto a canvas rather than built out of widgets, so
/// the only way to see what it looks like is to read the pixels back.
/// Reading it back has to happen inside [WidgetTester.runAsync]: encoding an
/// image is real async work, and the fake-async zone a widget test runs in
/// never completes that future.
Future<List<Color>> _pixels(WidgetTester tester, Finder finder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);

  final colours = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    image.dispose();

    return [
      for (var i = 0; i < bytes.length; i += 4)
        Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]),
    ];
  });

  return colours!;
}

/// WCAG relative luminance, so the assertion is about legibility rather than
/// about the particular hexes the palette happens to hold.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

final _slices = [
  ChartSlice(label: 'Purlin sets', value: 237.6, shortLabel: 'MU-2201'),
  ChartSlice(label: 'Hall roof structure', value: 120, shortLabel: 'NM-118'),
];

Widget _harness() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: 600,
              height: 400,
              child: HoursByProjectChart(slices: _slices, windowDays: 30),
            ),
          ),
        ),
      ),
    );

void main() {
  tearDown(() => AppColors.palette = AppColors.paletteFor(ThemeController.defaultMode));

  testWidgets('the axis shows the project code, not a word of its name',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // "Purlin sets" used to be labelled "sets": the last word of the name
    // standing in for a code the name no longer carries.
    expect(find.text('MU-2201'), findsOneWidget);
    expect(find.text('sets'), findsNothing);
    expect(find.text('Purlin sets'), findsNothing);
  });

  for (final entry in [('dark', ThemeMode.dark), ('light', ThemeMode.light)]) {
    final (name, mode) = entry;

    test('the $name tooltip is legible against its own background', () {
      AppColors.palette = AppColors.paletteFor(mode);

      // What went wrong: in dark the bubble took textPrimary (near white) while
      // the text was hardcoded white, which lands at 1.2:1.
      expect(_contrast(AppColors.tooltipText, AppColors.tooltipSurface),
          greaterThan(4.5),
          reason: 'tooltip text on its bubble must clear WCAG AA');

      // And the bubble has to separate from the card it floats over.
      expect(_contrast(AppColors.tooltipSurface, AppColors.surface),
          greaterThan(1.2),
          reason: 'the tooltip must lift off the panel behind it');
    });
  }

  testWidgets('hovering a bar paints the tooltip in the palette bubble colour',
      (tester) async {
    AppColors.palette = AppColors.paletteFor(ThemeMode.dark);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final chart = find.byType(RepaintBoundary).first;

    final before = await _pixels(tester, chart);
    expect(before.where((c) => c == AppColors.tooltipSurface), isEmpty,
        reason: 'nothing is hovered yet, so no tooltip should be painted');

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    // fl_chart raises the tooltip from onHover, so the pointer has to *move*
    // within the chart rather than merely appear inside it.
    final box = tester.getRect(find.byType(HoursByProjectChart));
    await gesture.moveTo(box.center);
    await tester.pump();
    await gesture.moveTo(Offset(box.left + box.width * 0.3, box.top + box.height * 0.6));
    await tester.pumpAndSettle();

    final after = await _pixels(tester, chart);

    expect(after.where((c) => c == AppColors.tooltipSurface), isNotEmpty,
        reason: 'the bubble should be painted in tooltipSurface');
    expect(after.where((c) => c == const Color(0xFFFFFFFF)).length,
        lessThan(after.length ~/ 50),
        reason: 'the old bubble was near-white and swallowed the chart');
  });
}
