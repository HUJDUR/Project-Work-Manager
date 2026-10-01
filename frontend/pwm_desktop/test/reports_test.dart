import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/report_provider.dart';
import 'package:pwm_desktop/providers/reports_provider.dart';
import 'package:pwm_desktop/screens/reports_screen.dart';
import 'package:pwm_desktop/utils/app_roles.dart';

/// Stands in for one controller, applying the search object the way the API
/// would so the provider's paging and sorting stay pinned.
class _FakeProvider<T> extends BaseProvider<T> {
  @override
  T fromJson(dynamic data) => throw UnimplementedError();

  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;
  final List<Map<String, dynamic>> requests = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from((filter as Map?) ?? const {});
    requests.add(query);

    final page = query['page'] as int? ?? 1;
    final pageSize = query['pageSize'] as int? ?? rows.length;
    final start = (page - 1) * pageSize;
    final items = start >= rows.length
        ? <T>[]
        : rows.sublist(start, (start + pageSize).clamp(0, rows.length));

    return PageResult<T>()
      ..items = items
      ..totalCount = (query['includeTotalCount'] as bool? ?? false) ? rows.length : null;
  }
}

/// The PDF endpoints. Nothing here decodes a PDF — the bytes only have to be
/// the same object the provider hands to the preview. `status` answers
/// "Completed" immediately, standing in for `pwm.Worker` having already
/// rendered it by the time a test's `await` gets here.
class _FakeReportProvider extends ReportProvider {
  final List<Map<String, dynamic>> calls = [];
  final Map<int, Uint8List> _contentById = {};

  static final monthlyBytes = Uint8List.fromList(utf8.encode('%PDF-monthly'));
  static final transportBytes = Uint8List.fromList(utf8.encode('%PDF-transport'));
  static final rerunBytes = Uint8List.fromList(utf8.encode('%PDF-rerun'));

  /// Set to make the next call fail the way a dead API would.
  Object? failure;

  int _nextId = 100;

  @override
  Future<ReportQueueState> monthlyWorkHours({
    required int year,
    required int month,
    int? userId,
    int? projectId,
  }) async {
    calls.add({
      'action': 'MonthlyWorkHours',
      'year': year,
      'month': month,
      'userId': userId,
      'projectId': projectId,
    });
    if (failure case final error?) throw error;

    final id = _nextId++;
    _contentById[id] = monthlyBytes;
    return ReportQueueState(id: id, status: 'Completed');
  }

  @override
  Future<ReportQueueState> transportLoads({
    int? projectId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    calls.add({
      'action': 'TransportLoads',
      'projectId': projectId,
      'dateFrom': dateFrom?.toIso8601String(),
      'dateTo': dateTo?.toIso8601String(),
    });
    if (failure case final error?) throw error;

    final id = _nextId++;
    _contentById[id] = transportBytes;
    return ReportQueueState(id: id, status: 'Completed');
  }

  @override
  Future<ReportQueueState> status(int generatedReportId) async =>
      ReportQueueState(id: generatedReportId, status: 'Completed');

  @override
  Future<Uint8List> download(int generatedReportId) async {
    calls.add({'action': 'Download', 'id': generatedReportId});
    if (failure case final error?) throw error;
    return _contentById[generatedReportId] ?? rerunBytes;
  }
}

/// The screen is pinned to one month so the Period dropdown is deterministic.
final _today = DateTime(2026, 9, 2);

const _users = [
  User(
      id: 1,
      name: 'Nadir',
      surname: 'Hujdur',
      email: 'admin@pwm.ba',
      userTypeId: 1,
      isActive: true),
  User(
      id: 2,
      name: 'Emir',
      surname: 'Kovacevic',
      email: 'emir@pwm.ba',
      userTypeId: 3,
      isActive: true),
  User(
      id: 3,
      name: 'Vedran',
      surname: 'Alagic',
      email: 'vedran@pwm.ba',
      userTypeId: 3,
      isActive: false),
];

Project _project({required int id, required String name, required String code}) =>
    Project(
      id: id,
      customerId: 1,
      name: name,
      code: code,
      description: null,
      notes: null,
      priority: 2,
      createdByUserId: 1,
      weight: 1000,
      projectCategoryId: 1,
      creationDate: DateTime(2026, 6, 1),
      projectStatusId: 3,
      productionStartDate: DateTime(2026, 6, 1),
      deliveryDate: null,
      deliveryCompanyId: null,
    );

final _projects = [
  _project(id: 1, name: 'Hall roof structure', code: 'MU-2201'),
  _project(id: 2, name: 'Conveyor frame', code: 'AK-2202'),
];

/// `JsonSerializer.Serialize` writes the request's property names as declared,
/// so the stored parameters arrive in PascalCase.
final _generated = [
  GeneratedReport(
    id: 9,
    reportTypeId: 1,
    parameters: '{"Year":2026,"Month":6,"UserId":2,"ProjectId":null}',
    status: 'Completed',
  ),
  GeneratedReport(
    id: 8,
    reportTypeId: 2,
    parameters:
        '{"ProjectId":1,"DateFrom":"2026-05-31T22:00:00Z","DateTo":"2026-06-30T21:59:59Z"}',
    status: 'Completed',
  ),
  GeneratedReport(
    id: 7,
    reportTypeId: 2,
    parameters: '{"ProjectId":null,"DateFrom":null,"DateTo":null}',
    status: 'Completed',
  ),
];

/// Who ran each report and when. `GeneratedReports` holds neither any more —
/// the activity log entry pointing back at the report is the record of the run.
final _reportLogTypes = [
  ActivityLogType(id: 20, name: 'Generated report - Monthly Work Hours'),
  ActivityLogType(id: 21, name: 'Generated report - Transport & Loads'),
  ActivityLogType(id: 1, name: 'Log In'),
];

final _reportRuns = [
  ActivityLog(
    id: 500,
    userId: 1,
    activityLogTypeId: 20,
    generatedReportId: 9,
    date: DateTime(2026, 7, 1, 9, 30),
  ),
  ActivityLog(
    id: 501,
    userId: 1,
    activityLogTypeId: 21,
    generatedReportId: 8,
    date: DateTime(2026, 6, 30, 16, 0),
  ),
  ActivityLog(
    id: 502,
    userId: 2,
    activityLogTypeId: 21,
    generatedReportId: 7,
    date: DateTime(2026, 6, 20, 11, 0),
  ),
];

late _FakeReportProvider _reports;
late _FakeProvider<GeneratedReport> _generatedRows;

ReportsProvider _fakeReports({String role = AppRoles.admin, DateTime? monthlyPeriod}) {
  _reports = _FakeReportProvider();
  _generatedRows = _FakeProvider(_generated);

  return ReportsProvider(
    reports: _reports,
    generatedReports: _generatedRows,
    activityLogs: _FakeProvider(_reportRuns),
    activityLogTypes: _FakeProvider(_reportLogTypes),
    users: _FakeProvider(_users),
    projects: _FakeProvider(_projects),
    today: _today,
    role: role,
    monthlyPeriod: monthlyPeriod,
  );
}

void main() {
  group('opened from Monthly Reports', () {
    test('fills the form with that month, and leaves generating to the user', () async {
      final provider = _fakeReports(monthlyPeriod: DateTime(2026, 7));
      await provider.load();

      expect(provider.type, ReportType.monthlyWorkHours);
      expect(provider.period, DateTime(2026, 7));
      expect(_reports.calls, isEmpty);
      expect(provider.pdf, isNull);

      await provider.generate();
      expect(_reports.calls.first, containsPair('month', 7));
    });

    test('a month older than the Period dropdown is still offered', () async {
      final provider = _fakeReports(monthlyPeriod: DateTime(2023, 1));
      await provider.load();

      expect(provider.periods.last, DateTime(2023, 1));
    });

    test('a project manager gets the transports form', () async {
      final provider = _fakeReports(
        role: AppRoles.projectManager,
        monthlyPeriod: DateTime(2026, 7),
      );
      await provider.load();

      expect(provider.type, ReportType.transportLoads);
    });
  });

  group('ReportsProvider', () {
    late ReportsProvider provider;

    setUp(() async {
      provider = _fakeReports();
      await provider.load();
    });

    test('offers the active workers and every project as parameters', () {
      expect(provider.status, ReportsStatusState.ready);

      // A closed account cannot have hours booked against it any more.
      expect(provider.workers.map((user) => user.fullName),
          ['Emir Kovacevic', 'Nadir Hujdur']);
      expect(provider.projects.map((project) => project.name),
          ['Conveyor frame', 'Hall roof structure']);
    });

    test('opens on this month and reaches two years back', () {
      expect(provider.period, DateTime(2026, 9));
      expect(provider.periods.length, ReportsProvider.periodMonths);
      expect(provider.periods.first, DateTime(2026, 9));
      expect(provider.periods.last, DateTime(2024, 10));
      expect(ReportsProvider.periodLabel(provider.period), 'September 2026');
    });

    test('asks the API for the newest runs', () {
      final request = _generatedRows.requests.single;

      expect(request['page'], 1);
      expect(request['pageSize'], ReportsProvider.recentCount);
      expect(request['sortBy'], ReportsProvider.recentSortBy);
      expect(provider.recent.length, 3);
    });

    test('reads a past run back out of its stored parameters', () {
      final monthly = provider.recent.firstWhere((report) => report.id == 9);
      expect(monthly.title, 'Monthly Work Hours');
      expect(monthly.summary, 'June 2026 · Emir Kovacevic · All projects');
      expect(monthly.generatedByName, 'Nadir Hujdur');

      final transport = provider.recent.firstWhere((report) => report.id == 8);
      expect(transport.title, 'Transport & Loads');
      expect(transport.summary, 'Hall roof structure · 01.06.2026. - 30.06.2026.');

      // Every parameter left null reads as the report covering everything.
      final everything = provider.recent.firstWhere((report) => report.id == 7);
      expect(everything.summary, 'All projects · All dates');
    });

    test('posts the monthly report with the parameters that were picked',
        () async {
      provider.setPeriod(DateTime(2026, 6));
      provider.setWorker(2);
      provider.setProject(1);

      await provider.generate();

      expect(_reports.calls.first, {
        'action': 'MonthlyWorkHours',
        'year': 2026,
        'month': 6,
        'userId': 2,
        'projectId': 1,
      });
      expect(provider.pdf, _FakeReportProvider.monthlyBytes);
      expect(provider.pdfLabel,
          'Monthly Work Hours · June 2026 · Emir Kovacevic · Hall roof structure');
      expect(provider.fileName, 'monthly-work-hours-2026-06.pdf');
      expect(provider.errorMessage, isNull);
    });

    test('posts the transport report and closes its range on the last second',
        () async {
      provider.setType(ReportType.transportLoads);
      provider.setDateRange(
        DateTimeRange(start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 30)),
      );

      await provider.generate();

      final call = _reports.calls.first;
      expect(call['action'], 'TransportLoads');
      expect(call['projectId'], isNull);
      expect(DateTime.parse(call['dateFrom'] as String), DateTime(2026, 6, 1));
      expect(DateTime.parse(call['dateTo'] as String),
          DateTime(2026, 6, 30, 23, 59, 59));
      expect(provider.pdf, _FakeReportProvider.transportBytes);
      expect(provider.fileName, 'transport-loads.pdf');
    });

    test('refetches the recent list after a run, because a run writes a row',
        () async {
      await provider.generate();

      expect(_generatedRows.requests.length, 2);
      expect(provider.generating, isFalse);
    });

    test('re-runs a past report rather than opening a stored file', () async {
      final report = provider.recent.firstWhere((report) => report.id == 8);

      await provider.openRecent(report);

      expect(_reports.calls.single, {'action': 'Download', 'id': 8});
      expect(provider.pdf, _FakeReportProvider.rerunBytes);
      expect(provider.pdfLabel,
          'Transport & Loads · Hall roof structure · 01.06.2026. - 30.06.2026.');
    });

    test('keeps the API message when a run fails, and shows no document',
        () async {
      _reports.failure = Exception('boom');

      await provider.generate();

      expect(provider.pdf, isNull);
      expect(provider.errorMessage, contains('The report could not be generated'));
      expect(provider.generating, isFalse);
    });
  });

  testWidgets('reports screen renders the two report cards and the panels',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReportsScreen(providerFactory: _fakeReports)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Generate and download PDF reports'), findsOneWidget);
    expect(find.text('Monthly Work Hours'), findsWidgets);
    expect(find.text('Transport & Loads'), findsWidgets);
    expect(find.text('Generate Report'), findsOneWidget);

    // The monthly report is selected first, so it is its parameters on show.
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Worker'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);

    expect(find.text('Report Preview'), findsOneWidget);
    expect(find.text('No report generated yet'), findsOneWidget);
    expect(find.text('Recent Reports'), findsOneWidget);
    expect(find.text('June 2026 · Emir Kovacevic · All projects'), findsOneWidget);
  });

  testWidgets('picking Transport & Loads swaps the parameters it takes',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReportsScreen(providerFactory: _fakeReports)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(
      'Truck loads and transport records for a selected project, with driver, '
      'vehicle and weight details.',
    ));
    await tester.pumpAndSettle();

    // A month and a worker mean nothing to a report about trucks.
    expect(find.text('Period'), findsNothing);
    expect(find.text('Worker'), findsNothing);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Loaded between'), findsOneWidget);
    expect(find.text('All dates'), findsOneWidget);
  });

  testWidgets('Print, Download and Full screen wait for something to show',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReportsScreen(providerFactory: _fakeReports)),
    ));
    await tester.pumpAndSettle();

    final print = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Print'),
    );
    final download = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Download PDF'),
    );

    expect(print.onPressed, isNull);
    expect(download.onPressed, isNull);

    // There is nothing to blow up to full screen either.
    final fullScreen = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.open_in_full),
        matching: find.byType(IconButton),
      ),
    );
    expect(fullScreen.onPressed, isNull);
  });
}
