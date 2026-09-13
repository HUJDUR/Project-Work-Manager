import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/base_provider.dart';
import 'package:pwm_mobile/providers/clock_in_provider.dart';
import 'package:pwm_mobile/screens/clock_in_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

/// Reads back whatever it was given, and records every write so a test can see
/// exactly what the screen sent — an open session is only open because of what
/// is in the body.
class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows, {this.onInsert, this.onUpdate}) : super('Fake');

  List<T> rows;
  final T Function(Map<String, dynamic> body)? onInsert;
  final T Function(int id, Map<String, dynamic> body)? onUpdate;

  final List<Map<String, dynamic>> inserted = [];
  final List<({int id, Map<String, dynamic> body})> updated = [];
  final List<dynamic> filters = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    filters.add(filter);
    return PageResult<T>()..items = rows;
  }

  @override
  Future<T> getById(int id) async =>
      rows.firstWhere((row) => (row as dynamic).id == id);

  @override
  Future<T> insert(dynamic request) async {
    final body = Map<String, dynamic>.from(request as Map);
    inserted.add(body);
    return onInsert!(body);
  }

  @override
  Future<T> update(int id, [dynamic request]) async {
    final body = Map<String, dynamic>.from(request as Map);
    updated.add((id: id, body: body));

    final changed = onUpdate?.call(id, body);
    if (changed == null) return rows.first;

    // Written through, so a later read sees it — clocking out totals the day by
    // reading the shift's details back.
    rows = [
      for (final row in rows)
        if ((row as dynamic).id == id) changed else row,
    ];
    return changed;
  }
}

class _FailingProvider<T> extends BaseProvider<T> {
  _FailingProvider() : super('Fake');

  @override
  Future<PageResult<T>> get({dynamic filter}) async =>
      throw ApiClientException('The API is unreachable.');
}

final _now = DateTime(2026, 9, 13, 9, 0);

Project _project(int id, String code, String name) => Project(
      id: id,
      customerId: 1,
      name: name,
      code: code,
      weight: 1000,
      projectCategoryId: 1,
      creationDate: _now,
      projectStatusId: 2,
      createdByUserId: 1,
    );

WorkLogDetail _block({
  required int id,
  required int workLogId,
  DateTime? startedAt,
  DateTime? finishedAt,
  double hours = 0,
}) =>
    WorkLogDetail(
      id: id,
      workLogId: workLogId,
      userId: 20,
      operationTypeId: 15,
      projectId: 3,
      startedAt: startedAt ?? _now.subtract(const Duration(hours: 2)),
      finishedAt: finishedAt,
      hours: hours,
    );

/// Ids 1 Delivered / 2 In production, as the seeder numbers them.
List<ProjectStatusType> _statuses() => const [
      ProjectStatusType(id: 1, name: 'Delivered'),
      ProjectStatusType(id: 2, name: 'In production'),
    ];

List<OperationType> _operations() => const [
      OperationType(id: 9, name: 'Painting'),
      OperationType(id: 13, name: 'Grinding'),
      OperationType(id: 15, name: 'Welding'),
      OperationType(id: 99, name: 'CNC operator'),
    ];

/// Faruk is qualified for three of the four operations above.
List<UserOperation> _qualifications() => const [
      UserOperation(id: 1, userId: 20, operationTypeId: 9),
      UserOperation(id: 2, userId: 20, operationTypeId: 13),
      UserOperation(id: 3, userId: 20, operationTypeId: 15),
    ];

/// Today's shift, already open, as most tests start.
WorkLog _openShift() => WorkLog(
      id: 500,
      userId: 20,
      clockedIn: _now.subtract(const Duration(hours: 2)),
      hours: 0,
    );

({
  ClockInProvider provider,
  _FakeProvider<WorkLog> shifts,
  _FakeProvider<WorkLogDetail> blocks,
  _FakeProvider<Project> projects,
}) _build({
  List<WorkLogDetail> openBlocks = const [],
  List<WorkLog>? shiftRows,
}) {
  final shifts = _FakeProvider<WorkLog>(
    shiftRows ?? [_openShift()],
    onInsert: (body) => WorkLog(
      id: 501,
      userId: body['userId'] as int,
      clockedIn: DateTime.parse(body['clockedIn'] as String),
      hours: (body['hours'] as num).toDouble(),
    ),
    onUpdate: (id, body) => WorkLog(
      id: id,
      userId: body['userId'] as int,
      clockedIn: DateTime.parse(body['clockedIn'] as String),
      clockedOut: body['clockedOut'] == null
          ? null
          : DateTime.parse(body['clockedOut'] as String),
      hours: (body['hours'] as num).toDouble(),
    ),
  );

  WorkLogDetail detailFrom(int id, Map<String, dynamic> body) => WorkLogDetail(
        id: id,
        workLogId: body['workLogId'] as int,
        userId: body['userId'] as int,
        operationTypeId: body['operationTypeId'] as int,
        projectId: body['projectId'] as int,
        startedAt: DateTime.parse(body['startedAt'] as String),
        finishedAt: body['finishedAt'] == null
            ? null
            : DateTime.parse(body['finishedAt'] as String),
        hours: (body['hours'] as num).toDouble(),
      );

  final blocks = _FakeProvider<WorkLogDetail>(
    openBlocks,
    onUpdate: detailFrom,
    onInsert: (body) => WorkLogDetail(
      id: 900,
      workLogId: body['workLogId'] as int,
      userId: body['userId'] as int,
      operationTypeId: body['operationTypeId'] as int,
      projectId: body['projectId'] as int,
      startedAt: DateTime.parse(body['startedAt'] as String),
      hours: (body['hours'] as num).toDouble(),
    ),
  );

  final projects = _FakeProvider<Project>([
    _project(3, '26-015', 'Staircase module'),
    _project(1, '26-003', 'Hall roof structure'),
  ]);

  return (
    provider: ClockInProvider(
      workLogs: shifts,
      workLogDetails: blocks,
      projects: projects,
      projectStatuses: _FakeProvider<ProjectStatusType>(_statuses()),
      operationTypes: _FakeProvider<OperationType>(_operations()),
      userOperations: _FakeProvider<UserOperation>(_qualifications()),
      userId: 20,
      clock: () => _now,
    ),
    shifts: shifts,
    blocks: blocks,
    projects: projects,
  );
}

void main() {
  group('what can be picked', () {
    test('only the operations the worker is qualified for', () async {
      final fixture = _build();
      await fixture.provider.load();

      expect(
        fixture.provider.operationOptions.map((o) => o.name),
        ['Grinding', 'Painting', 'Welding'],
      );
      // Qualified for neither, so it is not on offer.
      expect(
        fixture.provider.operationOptions.any((o) => o.name == 'CNC operator'),
        isFalse,
      );
    });

    test('only projects in production, asked for by status id', () async {
      final fixture = _build();
      await fixture.provider.load();

      // "In production" is matched by name, and its id is what gets sent.
      expect(fixture.projects.filters.single['projectStatusId'], 2);
      // Sorted by code, so the list does not come back in row order.
      expect(fixture.provider.projectOptions.map((p) => p.code),
          ['26-003', '26-015']);
    });

    test('a pick that is no longer offered does not survive a reload', () async {
      final fixture = _build();
      await fixture.provider.load();

      fixture.provider.selectProject(3);
      fixture.provider.selectOperation(15);

      fixture.projects.rows = [_project(1, '26-003', 'Hall roof structure')];
      await fixture.provider.load();

      expect(fixture.provider.selectedProjectId, isNull);
      expect(fixture.provider.selectedOperationId, 15);
    });
  });

  group('clocking in', () {
    test('the first session of the day raises the shift', () async {
      // Yesterday's shift is not today's, so today's has to be made.
      final fixture = _build(shiftRows: [
        WorkLog(
          id: 400,
          userId: 20,
          clockedIn: _now.subtract(const Duration(days: 1)),
          clockedOut: _now.subtract(const Duration(days: 1, hours: -8)),
          hours: 8,
        ),
      ]);
      await fixture.provider.load();

      fixture.provider.selectProject(3);
      fixture.provider.selectOperation(15);
      await fixture.provider.clockIn();

      final shift = fixture.shifts.inserted.single;
      expect(shift['userId'], 20);
      expect(shift['clockedIn'], _now.toIso8601String());
      // The whole point: no end time, so the session reads as running.
      expect(shift['clockedOut'], isNull);
      expect(shift['hours'], 0);

      expect(fixture.blocks.inserted.single['workLogId'], 501);
    });

    test("a later session joins the day's shift instead of raising another",
        () async {
      // Today's shift is already open, from an earlier session.
      final fixture = _build();
      await fixture.provider.load();

      fixture.provider.selectProject(3);
      fixture.provider.selectOperation(15);
      await fixture.provider.clockIn();

      // A WorkLog is the day, not the session — so nothing new is raised.
      expect(fixture.shifts.inserted, isEmpty);

      final block = fixture.blocks.inserted.single;
      expect(block['workLogId'], 500, reason: "hangs off today's shift");
      expect(block['projectId'], 3);
      expect(block['operationTypeId'], 15);
      expect(block['startedAt'], _now.toIso8601String());
      expect(block['finishedAt'], isNull);
    });

    test('a day already clocked out of is reopened, not duplicated', () async {
      final fixture = _build(shiftRows: [
        WorkLog(
          id: 500,
          userId: 20,
          clockedIn: _now.subtract(const Duration(hours: 4)),
          clockedOut: _now.subtract(const Duration(hours: 1)),
          hours: 3,
        ),
      ]);
      await fixture.provider.load();

      fixture.provider.selectProject(3);
      fixture.provider.selectOperation(15);
      await fixture.provider.clockIn();

      expect(fixture.shifts.inserted, isEmpty);

      final reopened = fixture.shifts.updated.single;
      expect(reopened.id, 500);
      // Back on the clock, with the morning's hours and start untouched.
      expect(reopened.body['clockedOut'], isNull);
      expect(reopened.body['hours'], 3);
      expect(reopened.body['clockedIn'],
          _now.subtract(const Duration(hours: 4)).toIso8601String());
    });

    test('the session becomes the active one, named', () async {
      final fixture = _build();
      await fixture.provider.load();

      fixture.provider.selectProject(3);
      fixture.provider.selectOperation(15);
      await fixture.provider.clockIn();

      final active = fixture.provider.active!;
      expect(active.projectLabel, '26-015 - Staircase module');
      expect(active.operationName, 'Welding');
      expect(fixture.provider.hasActiveSession, isTrue);
      // The form is cleared, so the next session starts from nothing.
      expect(fixture.provider.selectedProjectId, isNull);
    });

    test('will not start a second session on top of a running one', () async {
      final fixture = _build(openBlocks: [_block(id: 900, workLogId: 500)]);
      await fixture.provider.load();

      expect(fixture.provider.hasActiveSession, isTrue);
      expect(fixture.provider.canClockIn, isFalse);
      expect(fixture.provider.clockInBlockedReason,
          'Clock out of your current session first.');
    });

    test('says what is missing before anything is picked', () async {
      final fixture = _build();
      await fixture.provider.load();

      expect(fixture.provider.clockInBlockedReason,
          'Pick a project and an operation.');

      fixture.provider.selectProject(3);
      expect(fixture.provider.canClockIn, isFalse);

      fixture.provider.selectOperation(15);
      expect(fixture.provider.canClockIn, isTrue);
    });
  });

  group('clocking out', () {
    test('closes the block and its shift at the same moment', () async {
      final started = _now.subtract(const Duration(hours: 1, minutes: 30));
      final fixture = _build(
        openBlocks: [_block(id: 900, workLogId: 500, startedAt: started)],
      );
      await fixture.provider.load();
      await fixture.provider.clockOut();

      final block = fixture.blocks.updated.single;
      expect(block.id, 900);
      expect(block.body['finishedAt'], _now.toIso8601String());
      expect(block.body['hours'], 1.5);
      // The start must survive the write untouched.
      expect(block.body['startedAt'], started.toIso8601String());

      final shift = fixture.shifts.updated.single;
      expect(shift.id, 500);
      expect(shift.body['clockedOut'], _now.toIso8601String());
      expect(shift.body['hours'], 1.5);

      expect(fixture.provider.hasActiveSession, isFalse);
    });

    test("the shift's hours are the day's operations totalled, not the session's",
        () async {
      final fixture = _build(
        openBlocks: [
          // Two operations already booked today, plus the one running.
          _block(
            id: 898,
            workLogId: 500,
            startedAt: _now.subtract(const Duration(hours: 5)),
            finishedAt: _now.subtract(const Duration(hours: 3)),
            hours: 2,
          ),
          _block(
            id: 899,
            workLogId: 500,
            startedAt: _now.subtract(const Duration(hours: 3)),
            finishedAt: _now.subtract(const Duration(hours: 1, minutes: 30)),
            hours: 1.5,
          ),
          _block(
            id: 900,
            workLogId: 500,
            startedAt: _now.subtract(const Duration(hours: 1, minutes: 30)),
          ),
        ],
      );
      await fixture.provider.load();
      await fixture.provider.clockOut();

      // The session was 1.5, but the day is 2 + 1.5 + 1.5.
      expect(fixture.blocks.updated.single.body['hours'], 1.5);
      expect(fixture.shifts.updated.single.body['hours'], 5.0);
    });

    test('hours are the time actually elapsed, to two places', () async {
      final fixture = _build(
        openBlocks: [
          _block(
            id: 900,
            workLogId: 500,
            startedAt: _now.subtract(const Duration(minutes: 100)),
          ),
        ],
      );
      await fixture.provider.load();
      await fixture.provider.clockOut();

      // 100 minutes is 1.666... hours.
      expect(fixture.blocks.updated.single.body['hours'], 1.67);
    });
  });

  group('finding a session left running', () {
    test('an unfinished block becomes the active session', () async {
      final fixture = _build(openBlocks: [_block(id: 900, workLogId: 500)]);
      await fixture.provider.load();

      expect(fixture.provider.active?.id, 900);
      expect(fixture.provider.active?.projectLabel, '26-015 - Staircase module');
    });

    test('a finished block is not a running session', () async {
      final fixture = _build(openBlocks: [
        _block(id: 900, workLogId: 500, finishedAt: _now, hours: 2),
      ]);
      await fixture.provider.load();

      expect(fixture.provider.hasActiveSession, isFalse);
    });

    test('one abandoned long ago is not silently resumed', () async {
      final fixture = _build(openBlocks: [
        _block(
          id: 900,
          workLogId: 500,
          // Older than the window, which an API ignoring dateFrom would return.
          startedAt: _now.subtract(const Duration(days: 9)),
        ),
      ]);
      await fixture.provider.load();

      expect(fixture.provider.hasActiveSession, isFalse);
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester, ClockInProvider provider) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClockInScreen(providerFactory: () => provider)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lays out both halves of the mockup', (tester) async {
      await pump(tester, _build().provider);

      expect(find.text('Active Session'), findsOneWidget);
      expect(find.text('Start New Session'), findsOneWidget);
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Operation'), findsOneWidget);
      expect(find.text('Clock In'), findsOneWidget);
      // Nothing is running, so there is nothing to clock out of.
      expect(find.text('Nothing running'), findsOneWidget);
      expect(find.text('Clock Out'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a running session shows its rows and the way out',
        (tester) async {
      final fixture = _build(
        openBlocks: [
          _block(
            id: 900,
            workLogId: 500,
            startedAt: _now.subtract(const Duration(hours: 1, minutes: 30)),
          ),
        ],
      );
      await pump(tester, fixture.provider);

      // Twice, as the mockup draws it: the card's title line and the Project row.
      expect(find.text('26-015 - Staircase module'), findsNWidgets(2));
      expect(find.text('Welding'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('Elapsed Time'), findsOneWidget);
      expect(find.text('Clock Out'), findsOneWidget);
      expect(find.text('Nothing running'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      await pump(
        tester,
        ClockInProvider(
          workLogs: _FailingProvider<WorkLog>(),
          workLogDetails: _FailingProvider<WorkLogDetail>(),
          projects: _FailingProvider<Project>(),
          projectStatuses: _FailingProvider<ProjectStatusType>(),
          operationTypes: _FailingProvider<OperationType>(),
          userOperations: _FailingProvider<UserOperation>(),
          userId: 20,
          clock: () => _now,
        ),
      );

      expect(find.text('The API is unreachable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
