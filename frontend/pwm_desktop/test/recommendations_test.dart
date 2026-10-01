import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/recommendation_api_provider.dart';
import 'package:pwm_desktop/providers/recommendations_provider.dart';
import 'package:pwm_desktop/screens/recommendations_screen.dart';
import 'package:pwm_desktop/utils/api_client_exception.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  @override
  T fromJson(dynamic data) => throw UnimplementedError();

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

/// Stands in for the API call so the provider's tests do not need HTTP.
class _FakeRecommendationApi extends RecommendationApiProvider {
  _FakeRecommendationApi(this._answer);

  /// Runs on every call, so a test can return a result or throw.
  final RecommendationResult Function() _answer;

  int calls = 0;
  int? lastCategoryId;
  double? lastTonnes;
  int? lastWorkingDays;

  @override
  Future<RecommendationResult> estimate({
    required int projectCategoryId,
    required double tonnes,
    required int workingDays,
  }) async {
    calls++;
    lastCategoryId = projectCategoryId;
    lastTonnes = tonnes;
    lastWorkingDays = workingDays;
    return _answer();
  }
}

const _categories = [
  ProjectCategory(id: 2, name: 'Sheet metal parts'),
  ProjectCategory(id: 1, name: 'Steel construction'),
  ProjectCategory(id: 3, name: 'Machining'),
];

RecommendationResult _readyResult() => const RecommendationResult(
      hasEstimate: true,
      explanation: 'Estimated by fitting a linear trend between tonnage and '
          'hours per work type across 5 past delivered "Steel construction" '
          'projects; that trend explains about 82.4% of the variation in the '
          'hours those projects actually took.',
      sampleSize: 5,
      accuracyPercent: 82.4,
      totalHours: 340.5,
      estimatedWorkers: 3,
      estimatedDurationDays: 14,
      workTypes: [
        RecommendationWorkType(
          operationTypeId: 1,
          operationTypeName: 'Welding',
          estimatedHours: 210.5,
          sharePercent: 61.8,
        ),
        RecommendationWorkType(
          operationTypeId: 2,
          operationTypeName: 'Painting',
          estimatedHours: 130,
          sharePercent: 38.2,
        ),
      ],
    );

RecommendationResult _notEnoughDataResult() => const RecommendationResult(
      hasEstimate: false,
      message: 'Only 1 delivered project(s) of "Steel construction" so far; '
          'at least 3 are needed before an estimate is shown.',
      sampleSize: 1,
      accuracyPercent: 0,
      totalHours: 0,
      estimatedWorkers: 0,
      estimatedDurationDays: 0,
      workTypes: [],
    );

RecommendationsProvider _fakeRecommendations({RecommendationApiProvider? api}) =>
    RecommendationsProvider(
      categories: _FakeProvider(_categories),
      recommendationApi: api ?? _FakeRecommendationApi(_readyResult),
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

    test('estimate() sends the three inputs and stores the answer', () async {
      final api = _FakeRecommendationApi(_readyResult);
      provider = _fakeRecommendations(api: api);
      await provider.load();

      provider.setCategory(1);
      provider.setTonnes('12');
      provider.setWorkingDays('20');

      await provider.estimate();

      expect(api.calls, 1);
      expect(api.lastCategoryId, 1);
      expect(api.lastTonnes, 12);
      expect(api.lastWorkingDays, 20);

      expect(provider.asked, isTrue);
      expect(provider.estimating, isFalse);
      expect(provider.hasEstimate, isTrue);
      expect(provider.totalHours, 340.5);
      expect(provider.estimatedWorkers, 3);
      expect(provider.estimatedDurationDays, 14);
      expect(provider.sampleSize, 5);
      expect(provider.explanation, contains('5 past delivered'));
      expect(provider.workTypes, hasLength(2));
      expect(provider.workTypes.first.operationTypeName, 'Welding');
    });

    test('estimate() surfaces a not-enough-history answer without inventing numbers',
        () async {
      provider = _fakeRecommendations(api: _FakeRecommendationApi(_notEnoughDataResult));
      await provider.load();

      provider.setCategory(1);
      provider.setTonnes('12');
      provider.setWorkingDays('20');

      await provider.estimate();

      expect(provider.hasEstimate, isFalse);
      expect(provider.noDataMessage, contains('at least 3 are needed'));
      expect(provider.totalHours, 0);
    });

    test('estimate() surfaces the API error message', () async {
      provider = _fakeRecommendations(
        api: _FakeRecommendationApi(
          () => throw ApiClientException('Expected tonnage has to be greater than zero.'),
        ),
      );
      await provider.load();

      provider.setCategory(1);
      provider.setTonnes('12');
      provider.setWorkingDays('20');

      await provider.estimate();

      expect(provider.hasEstimate, isFalse);
      expect(provider.estimateError, 'Expected tonnage has to be greater than zero.');
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

  testWidgets('Estimate stays disabled until the inputs are filled in, then renders the answer',
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

    // The fake API answered with a real estimate, so the table breaks it down
    // by work type rather than saying anything is missing.
    expect(find.text('Welding'), findsOneWidget);
    expect(find.text('Painting'), findsOneWidget);
    expect(find.text('No estimate yet'), findsNothing);

    // Explainable, not a bare number: the "why" behind the estimate is shown.
    expect(find.textContaining('5 past delivered'), findsOneWidget);
  });

  testWidgets('a category with too little history explains why, not a blank table',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecommendationsScreen(
          providerFactory: () => _fakeRecommendations(
            api: _FakeRecommendationApi(_notEnoughDataResult),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

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

    expect(find.text('Not enough history yet'), findsOneWidget);
    expect(find.textContaining('at least 3 are needed'), findsOneWidget);
  });
}
