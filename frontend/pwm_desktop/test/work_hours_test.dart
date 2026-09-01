import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/work_hours_provider.dart';
import 'package:pwm_desktop/screens/work_hours_screen.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;

  /// What was written, so a test can read the bodies back.
  final List<Map<String, dynamic>> inserted = [];
  final List<(int, Map<String, dynamic>)> updated = [];
  final List<int> removed = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async => PageResult<T>()..items = rows;

  @override
  Future<T> insert(dynamic request) async {
    inserted.add(Map<String, dynamic>.from(request as Map));
    return rows.first;
  }

  @override
  Future<T> update(int id, [dynamic request]) async {
    updated.add((id, Map<String, dynamic>.from(request as Map)));
    return rows.firstWhere((row) => (row as dynamic).id == id, orElse: () => rows.first);
  }

  @override
  Future remove(int id) async => removed.add(id);
}

final _today = DateUtils.dateOnly(DateTime.now());
final _lastWeek = _today.subtract(const Duration(days: 7));

WorkLog _shift(int id, int userId, DateTime day) => WorkLog(
      id: id,
      userId: userId,
      clockedIn: day.add(const Duration(hours: 7)),
      clockedOut: day.add(const Duration(hours: 16)),
      hours: 9,
    );

WorkLogDetail _booking({
  required int id,
  required int workLogId,
  required int projectId,
  required DateTime start,
  required double hours,
}) =>
    WorkLogDetail(
      id: id,
      workLogId: workLogId,
      operationTypeId: 1,
      projectId: projectId,
      startedAt: start,
      finishedAt: start.add(Duration(minutes: (hours * 60).round())),
      hours: hours,
    );

late _FakeProvider<WorkLog> _shiftRows;
late _FakeProvider<WorkLogDetail> _bookingRows;

WorkHoursProvider _fakeWorkHours() => WorkHoursProvider(
      workLogs: _shiftRows = _FakeProvider([
        _shift(10, 1, _today),
        _shift(11, 2, _today),
        _shift(12, 1, _lastWeek),
      ]),
      workLogDetails: _bookingRows = _FakeProvider([
        _booking(
            id: 100,
            workLogId: 10,
            projectId: 1,
            start: _today.add(const Duration(hours: 7)),
            hours: 5),
        _booking(
            id: 101,
            workLogId: 10,
            projectId: 2,
            start: _today.add(const Duration(hours: 12)),
            hours: 4),
        _booking(
            id: 102,
            workLogId: 11,
            projectId: 1,
            start: _today.add(const Duration(hours: 7)),
            hours: 6),
        _booking(
            id: 103,
            workLogId: 12,
            projectId: 1,
            start: _lastWeek.add(const Duration(hours: 7)),
            hours: 3),
      ]),
      users: _FakeProvider(const [
        User(
            id: 1,
            name: 'Emir',
            surname: 'Kovacevic',
            email: 'e@pwm.ba',
            userTypeId: 3,
            isActive: true),
        User(
            id: 2,
            name: 'Damir',
            surname: 'Softic',
            email: 'd@pwm.ba',
            userTypeId: 3,
            isActive: true),
        User(
            id: 4,
            name: 'Selma',
            surname: 'Delic',
            email: 's@pwm.ba',
            userTypeId: 2,
            isActive: true),
      ]),
      userTypes: _FakeProvider(const [
        UserType(id: 2, type: 'Manager'),
        UserType(id: 3, type: 'Worker'),
      ]),
      projects: _FakeProvider([
        Project(
            id: 1,
            customerId: 1,
            name: 'Hall roof MU-1',
            code: 'MU-1',
            weight: 1000,
            projectCategoryId: 1,
            creationDate: _today,
            projectStatusId: 3,
            createdByUserId: 1),
        Project(
            id: 2,
            customerId: 1,
            name: 'Railing MU-2',
            code: 'MU-2',
            weight: 500,
            projectCategoryId: 1,
            creationDate: _today,
            projectStatusId: 3,
            createdByUserId: 1),
      ]),
      operationTypes: _FakeProvider(const [OperationType(id: 1, name: 'Welding')]),
    );

void main() {
  group('WorkHoursProvider', () {
    late WorkHoursProvider provider;

    setUp(() async {
      provider = _fakeWorkHours();
      await provider.load();
    });

    test('builds one row per booking, newest first', () {
      expect(provider.status, WorkHoursStatusState.ready);
      expect(provider.entries.length, 4);
      expect(provider.entries.first.date.isAfter(provider.entries.last.date), isTrue);
    });

    test('treats a worker-day past eight hours as overtime', () {
      final byId = {for (final entry in provider.entries) entry.id: entry};

      expect(byId[100]!.regularHours, 5);
      expect(byId[100]!.overtimeHours, 0);
      // The second booking of the day crosses the eight-hour line at 3 h.
      expect(byId[101]!.regularHours, 3);
      expect(byId[101]!.overtimeHours, 1);
      expect(byId[102]!.overtimeHours, 0);
    });

    test('totals the visible rows', () {
      expect(provider.totalHours, 18);
      expect(provider.regularHours, 17);
      expect(provider.overtimeHours, 1);
      expect(provider.workerCount, 2);
    });

    test('filters by worker name', () {
      provider.setSearch('kovacevic');

      expect(provider.entries.map((entry) => entry.workerName).toSet(),
          {'Emir Kovacevic'});
      expect(provider.workerCount, 1);
    });

    test('filters by project', () {
      provider.setProject(2);

      expect(provider.entries.single.projectName, 'Railing MU-2');
    });

    test('filters by date range', () {
      provider.setDateRange(DateTimeRange(start: _today, end: _today));

      expect(provider.entries.length, 3);
      expect(provider.totalHours, 15);
    });

    test('filters down to overtime rows', () {
      provider.setOvertimeOnly(true);

      expect(provider.entries.single.id, 101);
    });

    test('clears every filter at once', () {
      provider
        ..setSearch('emir')
        ..setProject(1)
        ..setOvertimeOnly(true);
      expect(provider.hasFilters, isTrue);

      provider.clearFilters();

      expect(provider.hasFilters, isFalse);
      expect(provider.entries.length, 4);
    });

    test('offers only active workers for a new entry', () {
      expect(provider.workers.map((worker) => worker.fullName),
          ['Damir Softic', 'Emir Kovacevic']);
    });

    test('carries the ids and both timestamps a details form writes back', () {
      final entry = provider.entries.firstWhere((entry) => entry.id == 101);

      expect(entry.workLogId, 10);
      expect(entry.operationTypeId, 1);
      expect(entry.startedAt, _today.add(const Duration(hours: 12)));
      expect(entry.finishedAt, isNotNull);
    });

    test('books new hours as a shift and a block against it', () async {
      await provider.saveWorkHours(
        userId: 2,
        projectId: 1,
        operationTypeId: 3,
        startedAt: DateTime(2026, 8, 31, 7),
        finishedAt: DateTime(2026, 8, 31, 15, 30),
      );

      final shift = _shiftRows.inserted.single;
      expect(shift['userId'], 2);
      expect(shift['hours'], 8.5);

      final block = _bookingRows.inserted.single;
      expect(block['workLogId'], 10);
      expect(block['projectId'], 1);
      expect(block['operationTypeId'], 3);
      expect(block['hours'], 8.5);
    });

    test('puts an edited block and its shift back rather than adding a second',
        () async {
      final entry = provider.entries.firstWhere((entry) => entry.id == 103);

      await provider.saveWorkHours(
        id: entry.id,
        workLogId: entry.workLogId,
        userId: entry.userId,
        projectId: 2,
        operationTypeId: entry.operationTypeId,
        startedAt: DateTime(2026, 8, 24, 7),
        finishedAt: DateTime(2026, 8, 24, 11),
      );

      expect(_shiftRows.updated.single.$1, 12);
      final (id, block) = _bookingRows.updated.single;
      expect(id, 103);
      expect(block['projectId'], 2);
      expect(block['hours'], 4);
      expect(_bookingRows.inserted, isEmpty);
    });

    test('deletes the shift with the last block booked against it', () async {
      // Shift 12 carries only booking 103.
      await provider.deleteWorkHours(
          provider.entries.firstWhere((entry) => entry.id == 103));

      expect(_bookingRows.removed, [103]);
      expect(_shiftRows.removed, [12]);
    });

    test('keeps a shift that still has other blocks on it', () async {
      // Shift 10 carries bookings 100 and 101.
      await provider.deleteWorkHours(
          provider.entries.firstWhere((entry) => entry.id == 100));

      expect(_bookingRows.removed, [100]);
      expect(_shiftRows.removed, isEmpty);
    });
  });

  testWidgets('work hours screen renders the summary and the table', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WorkHoursScreen(providerFactory: _fakeWorkHours)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Work Hours'), findsOneWidget);
    expect(find.text('Overview of all recorded work hours'), findsOneWidget);
    expect(find.text('Add Work Hours'), findsOneWidget);

    expect(find.text('Total Hours'), findsNWidgets(2));
    expect(find.text('Overtime Hours'), findsNWidgets(2));
    expect(find.text('18 h'), findsOneWidget);

    expect(find.text('Emir Kovacevic'), findsWidgets);
    expect(find.text('Hall roof MU-1'), findsWidgets);
    expect(find.text('Completed'), findsNWidgets(4));
  });
}
