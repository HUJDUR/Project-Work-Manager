import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/work_hours_provider.dart';
import 'package:pwm_desktop/screens/work_hours_screen.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  @override
  T fromJson(dynamic data) => throw UnimplementedError();

  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;

  /// The query each read was sent with, so a test can check what was asked.
  final List<Map<String, dynamic>> filters = [];

  /// What was written, so a test can read the bodies back.
  final List<Map<String, dynamic>> inserted = [];
  final List<(int, Map<String, dynamic>)> updated = [];
  final List<int> removed = [];

  Map<String, dynamic> get lastFilter => filters.last;

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    filters.add(Map<String, dynamic>.from(filter as Map? ?? const {}));
    return PageResult<T>()..items = rows;
  }

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

/// A row as `GET /WorkLogDetail/Hours` hands it over - already joined and split.
WorkHoursEntry _entry({
  required int id,
  required int workLogId,
  required int userId,
  required String worker,
  required int projectId,
  required String project,
  required DateTime start,
  required double regular,
  double overtime = 0,
}) {
  final hours = regular + overtime;
  return WorkHoursEntry(
    id: id,
    workLogId: workLogId,
    userId: userId,
    projectId: projectId,
    operationTypeId: 1,
    workerName: worker,
    workerInitials: worker.split(' ').map((part) => part[0]).join(),
    projectName: project,
    operationName: 'Welding',
    date: start,
    startedAt: start,
    finishedAt: start.add(Duration(minutes: (hours * 60).round())),
    regularHours: regular,
    overtimeHours: overtime,
    status: WorkHoursStatus.completed,
  );
}

late _FakeProvider<WorkHoursEntry> _hourRows;
late _FakeProvider<WorkLog> _shiftRows;
late _FakeProvider<WorkLogDetail> _bookingRows;
late _FakeProvider<User> _userRows;

WorkHoursProvider _fakeWorkHours() => WorkHoursProvider(
      hours: _hourRows = _FakeProvider([
        _entry(
            id: 101,
            workLogId: 10,
            userId: 1,
            worker: 'Emir Kovacevic',
            projectId: 2,
            project: 'Railing MU-2',
            start: _today.add(const Duration(hours: 12)),
            regular: 3,
            overtime: 1),
        _entry(
            id: 100,
            workLogId: 10,
            userId: 1,
            worker: 'Emir Kovacevic',
            projectId: 1,
            project: 'Hall roof MU-1',
            start: _today.add(const Duration(hours: 7)),
            regular: 5),
        _entry(
            id: 102,
            workLogId: 11,
            userId: 2,
            worker: 'Damir Softic',
            projectId: 1,
            project: 'Hall roof MU-1',
            start: _today.add(const Duration(hours: 7)),
            regular: 6),
        _entry(
            id: 103,
            workLogId: 12,
            userId: 1,
            worker: 'Emir Kovacevic',
            projectId: 1,
            project: 'Hall roof MU-1',
            start: _lastWeek.add(const Duration(hours: 7)),
            regular: 3),
      ]),
      workLogs: _shiftRows = _FakeProvider([
        _shift(10, 1, _today),
        _shift(11, 2, _today),
        _shift(12, 1, _lastWeek),
      ]),
      workLogDetails: _bookingRows = _FakeProvider([
        WorkLogDetail(
            id: 103,
            workLogId: 12,
            userId: 1,
            operationTypeId: 1,
            projectId: 1,
            startedAt: _lastWeek.add(const Duration(hours: 7)),
            hours: 3),
      ]),
      // What the API answers for active production workers - unsorted, so the
      // provider's own ordering is what the test sees.
      users: _userRows = _FakeProvider(const [
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
      ]),
      userTypes: _FakeProvider(const [
        UserType(id: 2, type: 'Project manager'),
        UserType(id: 3, type: 'Production worker'),
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

    test('shows the rows the API answers with, in its order', () {
      expect(provider.status, WorkHoursStatusState.ready);
      expect(provider.entries.map((entry) => entry.id), [101, 100, 102, 103]);
    });

    test('asks for everything while no filter is set', () {
      final query = _hourRows.lastFilter;

      expect(query.keys.toSet(), {'page', 'pageSize', 'includeTotalCount'});
    });

    test('totals the rows it holds', () {
      expect(provider.totalHours, 18);
      expect(provider.regularHours, 17);
      expect(provider.overtimeHours, 1);
      expect(provider.workerCount, 2);
    });

    test('sends the worker search to the API', () async {
      await provider.setSearch(' kovacevic ');

      expect(_hourRows.lastFilter['search'], 'kovacevic');
    });

    test('sends the project to the API', () async {
      await provider.setProject(2);

      expect(_hourRows.lastFilter['projectId'], 2);
    });

    test('sends the date range to the API as whole days', () async {
      await provider.setDateRange(DateTimeRange(
          start: _lastWeek.add(const Duration(hours: 5)), end: _today));

      expect(_hourRows.lastFilter['dateFrom'], _lastWeek);
      expect(_hourRows.lastFilter['dateTo'], _today);
    });

    test('sends the hours filter by the name the API binds', () async {
      await provider.setHoursFilter(WorkHoursFilter.overtimeOnly);

      expect(_hourRows.lastFilter['hoursFilter'], 'OvertimeOnly');
    });

    test('clears every filter at once', () async {
      await provider.setSearch('emir');
      await provider.setProject(1);
      await provider.setHoursFilter(WorkHoursFilter.overtimeOnly);
      expect(provider.hasFilters, isTrue);

      await provider.clearFilters();

      expect(provider.hasFilters, isFalse);
      expect(_hourRows.lastFilter.keys.toSet(), {'page', 'pageSize', 'includeTotalCount'});
    });

    test('asks the API for active production workers only, and sorts them', () {
      expect(_userRows.lastFilter['isActive'], isTrue);
      expect(_userRows.lastFilter['userTypeId'], 3);
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

    test('deletes a block in one call - the API removes an emptied shift itself',
        () async {
      await provider.deleteWorkHours(
          provider.entries.firstWhere((entry) => entry.id == 103));

      expect(_bookingRows.removed, [103]);
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

  testWidgets(
      'the worker and project fields on a new entry can be searched by name and code',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WorkHoursScreen(providerFactory: _fakeWorkHours)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Work Hours'));
    await tester.pumpAndSettle();

    // `DropdownMenu`'s own field sets `InputDecoration.label` (a `Text`
    // widget), not `labelText` - the plain string a `FormBuilderTextField`
    // uses - so both are checked.
    Finder fieldLabelled(String label) => find.byWidgetPredicate((widget) {
          if (widget is! TextField) return false;
          final decoration = widget.decoration;
          if (decoration?.labelText == label) return true;
          final labelWidget = decoration?.label;
          return labelWidget is Text && labelWidget.data == label;
        });

    final workerField = fieldLabelled('Worker');
    await tester.tap(workerField);
    await tester.pumpAndSettle();
    await tester.enterText(workerField, 'Softic');
    await tester.pumpAndSettle();

    expect(find.text('Damir Softic'), findsOneWidget);
    await tester.tap(find.text('Damir Softic').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(workerField).controller?.text, 'Damir Softic');

    final projectField = fieldLabelled('Project');
    await tester.tap(projectField);
    await tester.pumpAndSettle();
    // The two fixture projects' names share no words - only their codes do -
    // so matching one by the other's code proves the search checks the code.
    await tester.enterText(projectField, 'MU-2');
    await tester.pumpAndSettle();

    expect(find.text('MU-2 - Railing MU-2'), findsOneWidget);
    await tester.tap(find.text('MU-2 - Railing MU-2').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(projectField).controller?.text, 'MU-2 - Railing MU-2');
  });
}
