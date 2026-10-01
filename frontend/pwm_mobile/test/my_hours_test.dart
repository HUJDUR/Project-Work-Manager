import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/my_hours_provider.dart';
import 'package:pwm_mobile/providers/work_log_detail_provider.dart';
import 'package:pwm_mobile/screens/my_hours_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

/// `GET /WorkLogDetail/MyDays` as the API answers it: every day of the period
/// it holds, newest first, a page at a time, with the totals of all of them.
class _FakeDays extends WorkLogDetailProvider {
  _FakeDays(this.all);

  final List<WorkDay> all;

  /// Every request, so a test can show what the screen asked for.
  final List<({DateTime from, DateTime to, int page, int pageSize})> requests = [];

  @override
  Future<WorkDaysPage> myDays({
    required DateTime from,
    required DateTime to,
    required int page,
    required int pageSize,
  }) async {
    requests.add((from: from, to: to, page: page, pageSize: pageSize));

    return WorkDaysPage(
      days: all.skip((page - 1) * pageSize).take(pageSize).toList(),
      totalCount: all.length,
      totalHours: all.fold(0, (sum, day) => sum + day.hours),
      projectCount: all
          .expand((day) => day.entries.map((entry) => entry.projectCode))
          .toSet()
          .length,
      trend: [
        for (final day in all.reversed)
          WorkDayTotal(date: day.date, hours: day.hours, projectCount: day.projectCount),
      ],
    );
  }
}

class _FailingDays extends WorkLogDetailProvider {
  @override
  Future<WorkDaysPage> myDays({
    required DateTime from,
    required DateTime to,
    required int page,
    required int pageSize,
  }) async =>
      throw ApiClientException('The API is unreachable.');
}

/// A Wednesday, so "this week" has days either side of it.
final _now = DateTime(2026, 9, 9, 14, 30);
final _monday = DateTime(2026, 9, 7);

WorkEntry _entry(String code, String name, String operation, DateTime start, double hours,
        {String? note, bool open = false}) =>
    WorkEntry(
      projectName: name,
      projectCode: code,
      operationName: operation,
      startedAt: start,
      hours: hours,
      finishedAt: open ? null : start.add(Duration(minutes: (hours * 60).round())),
      note: note,
    );

WorkDay _day(DateTime date, List<WorkEntry> entries) => WorkDay(
      date: date,
      hours: entries.fold(0, (sum, entry) => sum + entry.hours),
      projectCount: entries.map((entry) => entry.projectCode).toSet().length,
      hasOpenBlock: entries.any((entry) => entry.isOpen),
      entries: entries,
    );

/// Tuesday: one block, 2h, on a project Monday already used. Monday: two
/// blocks, two projects, 6h. Newest first, as the API sends them.
List<WorkDay> _week() => [
      _day(DateTime(2026, 9, 8), [
        _entry('26-003', 'Hall roof structure', 'CNC helper', DateTime(2026, 9, 8, 8), 2,
            note: 'Waited for material.'),
      ]),
      _day(DateTime(2026, 9, 7), [
        _entry('26-003', 'Hall roof structure', 'CNC helper', DateTime(2026, 9, 7, 7), 4),
        _entry('26-004', 'Steel railings', 'Assembly', DateTime(2026, 9, 7, 12), 2),
      ]),
    ];

/// A whole month of weekdays - more than one page.
List<WorkDay> _month() => [
      for (var d = 30; d >= 1; d--)
        if (DateTime(2026, 9, d).weekday <= 5)
          _day(DateTime(2026, 9, d), [
            _entry('26-003', 'Hall roof structure', 'Welding', DateTime(2026, 9, d, 7), 8),
          ]),
    ];

MyHoursProvider _fake(WorkLogDetailProvider api) => MyHoursProvider(workLogDetails: api, clock: () => _now);

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

  group('loading', () {
    test('asks the API for the first page of the period', () async {
      final api = _FakeDays(_week());
      await _fake(api).load();

      final request = api.requests.single;
      expect(request.from, _monday);
      expect(request.to, DateTime(2026, 9, 14));
      expect(request.page, 1);
      expect(request.pageSize, MyHoursProvider.pageSize);
    });

    test('shows the days as the API sends them, newest first', () async {
      final provider = _fake(_FakeDays(_week()));
      await provider.load();

      expect(provider.status, MyHoursStatus.ready);
      expect(provider.days.map((d) => d.date), [DateTime(2026, 9, 8), DateTime(2026, 9, 7)]);
      expect(provider.days.last.hours, 6);
      expect(provider.days.last.projectCount, 2);
      expect(provider.hasMore, isFalse);
    });

    test('the totals are the whole period, counting each project once', () async {
      final provider = _fake(_FakeDays(_week()));
      await provider.load();

      expect(provider.totalHours, 8);
      expect(provider.projectCount, 2);
    });

    test('a day with an unfinished block reads as in progress', () async {
      final provider = _fake(_FakeDays([
        _day(DateTime(2026, 9, 9), [
          _entry('26-003', 'Hall roof structure', 'Welding', DateTime(2026, 9, 9, 7), 3, open: true),
        ]),
      ]));
      await provider.load();

      expect(provider.days.single.hasOpenBlock, isTrue);
    });
  });

  group('paging', () {
    test('loads one page, then the next under it, until there are no more', () async {
      final api = _FakeDays(_month());
      final provider = _fake(api);
      await provider.load();

      expect(provider.days, hasLength(MyHoursProvider.pageSize));
      expect(provider.hasMore, isTrue);
      // The totals already cover the whole month.
      expect(provider.totalHours, _month().length * 8);

      await provider.loadMore();
      expect(api.requests.last.page, 2);
      expect(provider.days, hasLength(20));

      await provider.loadMore();
      expect(provider.days, hasLength(_month().length));
      expect(provider.hasMore, isFalse);
      expect(provider.days.map((d) => d.date).toSet(), hasLength(_month().length));
    });

    test('changing the period starts again from the first page', () async {
      final api = _FakeDays(_month());
      final provider = _fake(api);
      await provider.load();
      await provider.loadMore();

      await provider.setPeriod(HoursPeriod.thisMonth);

      expect(api.requests.last.page, 1);
      expect(provider.days, hasLength(MyHoursProvider.pageSize));
    });
  });

  group('trends', () {
    test('there is one point per day of the period, gaps included', () async {
      final provider = _fake(_FakeDays(_week()));
      await provider.load();

      // Mon 6h, Tue 2h, then five empty days to Sunday.
      expect(provider.hoursTrend, [6, 2, 0, 0, 0, 0, 0]);
      expect(provider.projectsTrend, [2, 1, 0, 0, 0, 0, 0]);
    });

    test('an empty period has no series to draw', () async {
      final provider = _fake(_FakeDays([]));
      await provider.load();

      expect(provider.isEmpty, isTrue);
      expect(provider.hoursTrend, isEmpty);
    });
  });

  group('opening a day', () {
    test('its blocks come with their names and notes, in the order worked', () async {
      final provider = _fake(_FakeDays(_week()));
      await provider.load();

      final monday = await provider.entriesFor(provider.days.last);
      expect(monday.map((e) => e.projectLabel),
          ['26-003 - Hall roof structure', '26-004 - Steel railings']);
      expect(monday.first.operationName, 'CNC helper');

      final tuesday = await provider.entriesFor(provider.days.first);
      expect(tuesday.single.note, 'Waited for material.');
    });
  });

  group('failure', () {
    test('keeps the wording the API refused with', () async {
      final provider = _fake(_FailingDays());
      await provider.load();

      expect(provider.status, MyHoursStatus.failed);
      expect(provider.errorMessage, 'The API is unreachable.');
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
      await pump(tester, _fake(_FakeDays(_week())));

      expect(find.text('My Work Hours'), findsOneWidget);
      expect(find.text('Overview of your logged work hours'), findsOneWidget);
      expect(find.text('Total Hours'), findsOneWidget);
      expect(find.text('Projects Worked On'), findsOneWidget);
      expect(find.text('Work Hour Entries'), findsOneWidget);

      // One row per day, each with its own way into the detail.
      expect(find.text('View entries'), findsNWidgets(2));
      expect(find.text('Tue, 8 Sep'), findsOneWidget);
      expect(find.text('Mon, 7 Sep'), findsOneWidget);
      // Everything fits on one page, so there is nothing more to load.
      expect(find.text('Load more days'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a longer period loads more days on request', (tester) async {
      final api = _FakeDays(_month());
      await pump(tester, _fake(api));

      await tester.scrollUntilVisible(find.text('Load more days'), 300);
      await tester.tap(find.text('Load more days'));
      await tester.pumpAndSettle();

      expect(api.requests.last.page, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty period says so instead of showing an empty list', (tester) async {
      await pump(tester, _fake(_FakeDays([])));

      expect(find.text('Nothing booked this week'), findsOneWidget);
      expect(find.text('View entries'), findsNothing);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      await pump(tester, _fake(_FailingDays()));

      expect(find.text('The API is unreachable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
