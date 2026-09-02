import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/recommendations_provider.dart';
import 'package:pwm_desktop/screens/recommendations_screen.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from((filter as Map?) ?? const {});
    final page = query['page'] as int? ?? 1;
    final pageSize = query['pageSize'] as int? ?? rows.length;
    final start = (page - 1) * pageSize;

    return PageResult<T>()
      ..items = start >= rows.length
          ? <T>[]
          : rows.sublist(start, (start + pageSize).clamp(0, rows.length))
      ..totalCount = null;
  }
}

RecommendationsProvider _fakeRecommendations() => RecommendationsProvider(
      categories: _FakeProvider(const [
        ProjectCategory(id: 2, name: 'Sheet metal parts'),
        ProjectCategory(id: 1, name: 'Steel construction'),
        ProjectCategory(id: 3, name: 'Machining'),
      ]),
    );

void main() {
  group('RecommendationsProvider', () {
    late RecommendationsProvider provider;

    setUp(() async {
      provider = _fakeRecommendations();
      await provider.load();
    });

    test('offers the project types by name', () {
      expect(provider.status, RecommendationsStatusState.ready);
      expect(provider.categories.map((category) => category.name),
          ['Machining', 'Sheet metal parts', 'Steel construction']);
    });

    test('will not estimate until all three inputs are filled in', () {
      expect(provider.canEstimate, isFalse);

      provider.setCategory(1);
      expect(provider.canEstimate, isFalse);

      provider.setTonnes('12');
      expect(provider.canEstimate, isFalse);

      provider.setWorkingDays('20');
      expect(provider.canEstimate, isTrue);
    });

    test('reads a comma decimal the way the rest of the app does', () {
      provider.setTonnes('12,5');
      expect(provider.tonnes, 12.5);

      // Something that is not a number leaves nothing to estimate from.
      provider.setTonnes('twelve');
      expect(provider.tonnes, isNull);
    });

    test('rejects a tonnage or a deadline of zero', () {
      provider.setCategory(1);
      provider.setTonnes('0');
      provider.setWorkingDays('20');
      expect(provider.canEstimate, isFalse);

      provider.setTonnes('12');
      provider.setWorkingDays('0');
      expect(provider.canEstimate, isFalse);
    });

    test('has no estimator behind it yet', () {
      provider.setCategory(1);
      provider.setTonnes('12');
      provider.setWorkingDays('20');

      provider.estimate();

      // The button records that it was pressed; nothing computes an answer.
      expect(provider.asked, isTrue);
      expect(provider.hasEstimate, isFalse);
    });
  });

  testWidgets('recommendations screen renders the inputs, cards and table',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecommendationsScreen(providerFactory: _fakeRecommendations),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Project Resource Estimation'), findsOneWidget);
    expect(find.text('Select project type'), findsOneWidget);
    expect(find.text('Expected tonnage (t)'), findsOneWidget);
    expect(find.text('Deadline (working days)'), findsOneWidget);

    for (final card in const [
      'Total Estimated Hours',
      'Estimated Workers',
      'Estimated Duration',
      'Based On Projects',
    ]) {
      expect(find.text(card), findsOneWidget);
    }

    for (final column in const [
      'Work Type',
      'Distribution',
      'Estimated Hours',
      'Share',
    ]) {
      expect(find.text(column), findsOneWidget);
    }

    expect(find.text('Nothing to estimate yet'), findsOneWidget);
  });

  testWidgets('Estimate stays disabled until the inputs are filled in',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecommendationsScreen(providerFactory: _fakeRecommendations),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Estimate'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steel construction').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate((widget) =>
          widget is TextField && widget.decoration?.hintText == 'Expected tonnage (t)'),
      '12',
    );
    await tester.enterText(
      find.byWidgetPredicate((widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Deadline (working days)'),
      '20',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Estimate'));
    await tester.pumpAndSettle();

    // The screen says the estimator is missing rather than inventing numbers.
    expect(find.text('No estimate yet'), findsOneWidget);
  });
}
