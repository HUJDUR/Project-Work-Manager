import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/base_provider.dart';
import 'package:pwm_mobile/providers/dashboard_provider.dart';
import 'package:pwm_mobile/screens/dashboard_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  @override
  T fromJson(dynamic data) => throw UnimplementedError();

  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;

  /// The filter the screen sent, so a test can check the request was narrowed
  /// rather than the whole table being pulled and sifted here.
  dynamic lastFilter;

  /// How many times the screen has gone to the API, which is what tells a
  /// refresh apart from the first load.
  int loads = 0;

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    lastFilter = filter;
    loads++;
    return PageResult<T>()..items = rows;
  }
}

/// Hangs until [finish] is called, so a test can look at the screen while a
/// refresh is still in flight.
class _SlowProvider<T> extends _FakeProvider<T> {
  _SlowProvider(super.rows);

  Completer<void>? _pending;

  void finish() {
    _pending?.complete();
    _pending = null;
  }

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    // The first load resolves at once; a refresh is what waits.
    if (loads > 0) {
      final pending = _pending = Completer<void>();
      await pending.future;
    }
    return super.get(filter: filter);
  }
}

/// Answers once, then refuses — a refresh failing over figures already shown.
class _FlakyProvider<T> extends _FakeProvider<T> {
  _FlakyProvider(super.rows);

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    if (loads > 0) {
      throw ApiClientException('The API is unreachable.');
    }
    return super.get(filter: filter);
  }
}

class _FailingProvider<T> extends BaseProvider<T> {
  @override
  T fromJson(dynamic data) => throw UnimplementedError();

  _FailingProvider() : super('Fake');

  @override
  Future<PageResult<T>> get({dynamic filter}) async =>
      throw ApiClientException('The API is unreachable.');
}

/// A Wednesday, so the week has days either side of "today".
final _now = DateTime(2026, 9, 9, 14, 30);
final _today = DateTime(2026, 9, 9);
final _monday = DateTime(2026, 9, 7);

WorkLogDetail _block({
  required int id,
  required int projectId,
  required DateTime startedAt,
  required double hours,
}) =>
    WorkLogDetail(
      id: id,
      workLogId: 1,
      userId: 7,
      operationTypeId: 2,
      projectId: projectId,
      startedAt: startedAt,
      hours: hours,
    );

/// Two projects today (5.5 h), plus Monday's block on a project already counted
/// and Tuesday's on a third — so the week totals 12.25 h across three projects.
List<WorkLogDetail> _blocks() => [
      _block(id: 1, projectId: 11, startedAt: _today.add(const Duration(hours: 7)), hours: 3.5),
      _block(id: 2, projectId: 12, startedAt: _today.add(const Duration(hours: 11)), hours: 2),
      _block(id: 3, projectId: 11, startedAt: _monday.add(const Duration(hours: 8)), hours: 4),
      _block(id: 4, projectId: 13, startedAt: DateTime(2026, 9, 8, 9), hours: 2.75),
    ];

DashboardProvider _fakeDashboard([BaseProvider<WorkLogDetail>? blocks]) =>
    DashboardProvider(
      workLogDetails: blocks ?? _FakeProvider(_blocks()),
      userId: 7,
      clock: () => _now,
    );

Future<void> _pumpDashboard(WidgetTester tester, DashboardProvider provider) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DashboardScreen(providerFactory: () => provider))),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('today is the subset of the week that starts today', () async {
    final provider = _fakeDashboard();
    await provider.load();

    final summary = provider.summary!;
    expect(provider.status, DashboardStatus.ready);
    expect(summary.todayHours, 5.5);
    expect(summary.todayProjects, 2);
    expect(summary.weekHours, closeTo(12.25, 0.001));
    // The same project worked on twice counts once.
    expect(summary.weekProjects, 3);
    expect(summary.weekStart, _monday);
  });

  test('the week is asked of the API, not filtered out of a whole table', () async {
    final blocks = _FakeProvider(_blocks());
    await _fakeDashboard(blocks).load();

    // The token's account, not an id the app sends.
    expect(blocks.lastFilter['mine'], isTrue);
    expect(blocks.lastFilter.containsKey('userId'), isFalse);
    expect(blocks.lastFilter['dateFrom'], _monday);
  });

  test('a block older than the week cannot reach the totals', () async {
    final provider = DashboardProvider(
      // Whatever the API answers, last week's work is not this week's.
      workLogDetails: _FakeProvider([
        ..._blocks(),
        _block(id: 5, projectId: 99, startedAt: DateTime(2026, 9, 4, 9), hours: 8),
      ]),
      userId: 7,
      clock: () => _now,
    );
    await provider.load();

    expect(provider.summary!.weekHours, closeTo(12.25, 0.001));
    expect(provider.summary!.weekProjects, 3);
  });

  test('a failed load keeps the API\'s own wording', () async {
    final provider = DashboardProvider(
      workLogDetails: _FailingProvider<WorkLogDetail>(),
      userId: 7,
      clock: () => _now,
    );
    await provider.load();

    expect(provider.status, DashboardStatus.failed);
    expect(provider.errorMessage, 'The API is unreachable.');
  });

  test('no signed-in account is a failure, not an empty dashboard', () async {
    final provider = DashboardProvider(
      workLogDetails: _FakeProvider(_blocks()),
      userId: null,
      clock: () => _now,
    );
    await provider.load();

    expect(provider.status, DashboardStatus.failed);
    expect(provider.summary, isNull);
  });

  testWidgets('the summary cards read as the mockup does', (tester) async {
    await _pumpDashboard(tester, _fakeDashboard());

    expect(find.text("Today's Summary"), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Work Hours Today'), findsOneWidget);
    expect(find.text('Total Work Hours'), findsOneWidget);
    expect(find.text('Projects Worked On'), findsNWidgets(2));

    // Hours are shown as a shift reads, not as a decimal.
    expect(find.text('5h 30m'), findsOneWidget);
    expect(find.text('12h 15m'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('View all is offered only when the shell can act on it',
      (tester) async {
    await _pumpDashboard(tester, _fakeDashboard());
    expect(find.text('View all'), findsNothing);

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            providerFactory: _fakeDashboard,
            onViewAllHours: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View all'));
    expect(tapped, isTrue);
  });

  testWidgets('the refresh button reloads from the API', (tester) async {
    final blocks = _FakeProvider(_blocks());
    await _pumpDashboard(tester, _fakeDashboard(blocks));

    expect(blocks.loads, 1);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(blocks.loads, 2);
    // The numbers are still there — refreshing must not blank the screen.
    expect(find.text('5h 30m'), findsOneWidget);
  });

  testWidgets('refreshing keeps the figures and spins the button',
      (tester) async {
    final blocks = _SlowProvider(_blocks());
    await _pumpDashboard(tester, _fakeDashboard(blocks));

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();

    // Mid-flight: last week's answer stays up rather than flashing to a spinner.
    expect(find.text('5h 30m'), findsOneWidget);
    expect(find.byTooltip('Refreshing'), findsOneWidget);

    blocks.finish();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets('a refresh that fails keeps the old figures and says so',
      (tester) async {
    final provider = _fakeDashboard(_FlakyProvider(_blocks()));
    await _pumpDashboard(tester, provider);

    expect(find.text('5h 30m'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    // The full error state is for having nothing; here there is still data.
    expect(find.text('5h 30m'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(
      find.textContaining('Showing what was last loaded.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await _pumpDashboard(
      tester,
      DashboardProvider(
        workLogDetails: _FailingProvider<WorkLogDetail>(),
        userId: 7,
        clock: () => _now,
      ),
    );

    expect(find.text('The API is unreachable.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
