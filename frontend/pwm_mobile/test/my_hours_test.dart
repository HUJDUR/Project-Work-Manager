import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/base_provider.dart';
import 'package:pwm_mobile/providers/my_hours_provider.dart';
import 'package:pwm_mobile/screens/my_hours_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  @override
  T fromJson(dynamic data) => throw UnimplementedError();

  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;

  /// Every filter the screen sent, so a test can show the period reached the API.
  final List<dynamic> filters = [];

  /// Ids asked for one at a time, to pin the lazy lookup.
  final List<int> fetchedIds = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    filters.add(filter);
    return PageResult<T>()..items = rows;
  }

  @override
  Future<T> getById(int id) async {
    fetchedIds.add(id);
    return rows.firstWhere((row) => (row as dynamic).id == id);
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

/// A Wednesday, so "this week" has days either side of it.
final _now = DateTime(2026, 9, 9, 14, 30);
final _monday = DateTime(2026, 9, 7);

WorkLogDetail _block({
  required int id,
  required int projectId,
  required int operationTypeId,
  required DateTime startedAt,
  required double hours,
  DateTime? finishedAt,
}) =>
    WorkLogDetail(
      id: id,
      workLogId: 1,
      userId: 36,
      operationTypeId: operationTypeId,
      projectId: projectId,
      startedAt: startedAt,
      hours: hours,
      finishedAt: finishedAt ?? startedAt.add(Duration(minutes: (hours * 60).round())),
    );

/// Monday: two blocks, two projects, 6h. Tuesday: one block, 2h, on a project
/// Monday already used. Wednesday (today): nothing.
List<WorkLogDetail> _blocks() => [
      _block(id: 1, projectId: 11, operationTypeId: 2, startedAt: DateTime(2026, 9, 7, 7), hours: 4),
      _block(id: 2, projectId: 12, operationTypeId: 5, startedAt: DateTime(2026, 9, 7, 12), hours: 2),
      _block(id: 3, projectId: 11, operationTypeId: 2, startedAt: DateTime(2026, 9, 8, 8), hours: 2),
    ];

Project _project(int id, String name, String code) => Project(
      id: id,
      customerId: 1,
      name: name,
      code: code,
      weight: 1000,
      projectCategoryId: 1,
      creationDate: _now,
      projectStatusId: 1,
      createdByUserId: 1,
    );

List<Project> _projects() => [
      _project(11, 'Hall roof structure', '26-003'),
      _project(12, 'Steel railings', '26-004'),
    ];

List<OperationType> _operations() => const [
      OperationType(id: 2, name: 'CNC helper'),
      OperationType(id: 5, name: 'Assembly'),
    ];

MyHoursProvider _fake({
  List<WorkLogDetail>? blocks,
  BaseProvider<WorkLogDetail>? workLogDetails,
  BaseProvider<Project>? projects,
}) =>
    MyHoursProvider(
      workLogDetails: workLogDetails ?? _FakeProvider(blocks ?? _blocks()),
      projects: projects ?? _FakeProvider(_projects()),
      operationTypes: _FakeProvider(_operations()),
      userId: 36,
      clock: () => _now,
    );

void main() {
  group('periods', () {
    test('the week runs Monday to Sunday', () {
      final week = MyHoursProvider.rangeFor(HoursPeriod.thisWeek, _now);

      expect(week.from, _monday);
      // `to` is exclusive, so the week ends as the next Monday starts.
      expect(week.to, DateTime(2026, 9, 14));
    });

    test('last week is the seven days before this one', () {
      final week = MyHoursProvider.rangeFor(HoursPeriod.lastWeek, _now);

      expect(week.from, DateTime(2026, 8, 31));
      expect(week.to, _monday);
    });

    test('a month runs from the first to the first', () {
      expect(
        MyHoursProvider.rangeFor(HoursPeriod.thisMonth, _now),
        (from: DateTime(2026, 9, 1), to: DateTime(2026, 10, 1)),
      );
      expect(
        MyHoursProvider.rangeFor(HoursPeriod.lastMonth, _now),
        (from: DateTime(2026, 8, 1), to: DateTime(2026, 9, 1)),
      );
    });

    test('January rolls back into the previous year', () {
      expect(
        MyHoursProvider.rangeFor(HoursPeriod.lastMonth, DateTime(2026, 1, 15)),
        (from: DateTime(2025, 12, 1), to: DateTime(2026, 1, 1)),
      );
    });
  });

  group('grouping', () {
    test('blocks become days, newest first', () async {
      final provider = _fake();
      await provider.load();

      expect(provider.status, MyHoursStatus.ready);
      expect(provider.days.map((d) => d.date),
          [DateTime(2026, 9, 8), DateTime(2026, 9, 7)]);
      expect(provider.days.first.hours, 2);
      expect(provider.days.last.hours, 6);
      expect(provider.days.last.projectCount, 2);
    });

    test('the period total counts each project once across all its days',
        () async {
      final provider = _fake();
      await provider.load();

      expect(provider.totalHours, 8);
      // Project 11 was worked on Monday and Tuesday; it is still one project.
      expect(provider.projectCount, 2);
    });

    test('the period is asked of the API, not sliced out of everything',
        () async {
      final blocks = _FakeProvider(_blocks());
      await _fake(workLogDetails: blocks).load();

      expect(blocks.filters.single['userId'], 36);
      expect(blocks.filters.single['dateFrom'], _monday);
      expect(blocks.filters.single['dateTo'], DateTime(2026, 9, 14));
    });

    test('work outside the period cannot reach the totals', () async {
      final provider = _fake(blocks: [
        ..._blocks(),
        // Last week, which an API ignoring dateFrom would hand back.
        _block(id: 9, projectId: 99, operationTypeId: 2, startedAt: DateTime(2026, 9, 4, 8), hours: 8),
      ]);
      await provider.load();

      expect(provider.totalHours, 8);
      expect(provider.days.length, 2);
    });

    test('a day with an unfinished block reads as in progress', () async {
      final provider = _fake(blocks: [
        WorkLogDetail(
          id: 4,
          workLogId: 2,
          userId: 36,
          operationTypeId: 2,
          projectId: 11,
          startedAt: DateTime(2026, 9, 9, 7),
          hours: 3,
        ),
      ]);
      await provider.load();

      expect(provider.days.single.hasOpenBlock, isTrue);
    });
  });

  group('trends', () {
    test('there is one point per day of the period, gaps included', () async {
      final provider = _fake();
      await provider.load();

      // Mon 6h, Tue 2h, then five empty days to Sunday.
      expect(provider.hoursTrend, [6, 2, 0, 0, 0, 0, 0]);
      expect(provider.projectsTrend, [2, 1, 0, 0, 0, 0, 0]);
    });

    test('an empty period has no series to draw', () async {
      final provider = _fake(blocks: []);
      await provider.load();

      expect(provider.isEmpty, isTrue);
      expect(provider.hoursTrend, isEmpty);
    });
  });

  group('opening a day', () {
    test('resolves names only when asked, and only the ids it needs', () async {
      final projects = _FakeProvider(_projects());
      final provider = _fake(projects: projects);
      await provider.load();

      // Drawing the list must not have cost a single project lookup.
      expect(projects.fetchedIds, isEmpty);

      final monday = provider.days.last;
      final entries = await provider.entriesFor(monday);

      expect(projects.fetchedIds..sort(), [11, 12]);
      expect(entries.first.projectLabel, '26-003 - Hall roof structure');
      expect(entries.first.operationName, 'CNC helper');
    });

    test('a project already resolved is not fetched twice', () async {
      final projects = _FakeProvider(_projects());
      final provider = _fake(projects: projects);
      await provider.load();

      await provider.entriesFor(provider.days.last); // 11 and 12
      await provider.entriesFor(provider.days.first); // 11 again

      expect(projects.fetchedIds..sort(), [11, 12]);
    });
  });

  group('failure', () {
    test('keeps the wording the API refused with', () async {
      final provider = _fake(workLogDetails: _FailingProvider<WorkLogDetail>());
      await provider.load();

      expect(provider.status, MyHoursStatus.failed);
      expect(provider.errorMessage, 'The API is unreachable.');
    });

    test('no signed-in account is a failure, not an empty list', () async {
      final provider = MyHoursProvider(
        workLogDetails: _FakeProvider(_blocks()),
        projects: _FakeProvider(_projects()),
        operationTypes: _FakeProvider(_operations()),
        userId: null,
        clock: () => _now,
      );
      await provider.load();

      expect(provider.status, MyHoursStatus.failed);
      expect(provider.days, isEmpty);
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester, MyHoursProvider provider) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MyHoursScreen(providerFactory: () => provider)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lays out as the mockup does', (tester) async {
      await pump(tester, _fake());

      expect(find.text('My Work Hours'), findsOneWidget);
      expect(find.text('Overview of your logged work hours'), findsOneWidget);
      expect(find.text('Total Hours'), findsOneWidget);
      expect(find.text('Projects Worked On'), findsOneWidget);
      expect(find.text('Work Hour Entries'), findsOneWidget);

      // One row per day, each with its own way into the detail.
      expect(find.text('View entries'), findsNWidgets(2));
      expect(find.text('Tue, 8 Sep'), findsOneWidget);
      expect(find.text('Mon, 7 Sep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty period says so instead of showing an empty list',
        (tester) async {
      await pump(tester, _fake(blocks: []));

      expect(find.text('Nothing booked this week'), findsOneWidget);
      expect(find.text('View entries'), findsNothing);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      await pump(tester, _fake(workLogDetails: _FailingProvider<WorkLogDetail>()));

      expect(find.text('The API is unreachable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
