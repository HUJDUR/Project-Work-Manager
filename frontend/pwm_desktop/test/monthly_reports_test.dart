import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/layouts/master_navigation.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/monthly_hour_report_provider.dart';
import 'package:pwm_desktop/providers/monthly_reports_provider.dart';
import 'package:pwm_desktop/screens/monthly_report_details_screen.dart';
import 'package:pwm_desktop/screens/monthly_reports_screen.dart';
import 'package:pwm_desktop/utils/app_roles.dart';
import 'package:pwm_desktop/utils/sarajevo_time.dart';

MonthlyHourReport _month(int id, int year, int month, {double total = 100}) =>
    MonthlyHourReport(
      id: id,
      year: year,
      month: month,
      totalHours: total,
      regularHours: total - 10,
      overtimeHours: 10,
      workerCount: 3,
    );

/// Serves the months newest first and pages them the way the API would.
class _FakeApi extends MonthlyHourReportProvider {
  _FakeApi(this.rows);

  final List<MonthlyHourReport> rows;
  final List<Map<String, dynamic>> requests = [];

  @override
  Future<PageResult<MonthlyHourReport>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from(filter as Map);
    requests.add(query);

    final year = query['year'] as int?;
    final matching = rows.where((x) => year == null || x.year == year).toList();
    final page = query['page'] as int;
    final pageSize = query['pageSize'] as int;
    final start = (page - 1) * pageSize;

    return PageResult<MonthlyHourReport>()
      ..items = matching.skip(start).take(pageSize).toList()
      ..totalCount = matching.length;
  }

  @override
  Future<MonthlyHourReportOverview> overview(int id) async => MonthlyHourReportOverview(
        month: rows.firstWhere((x) => x.id == id),
        workers: const [
          MonthlyHourReportWorker(
            userId: 1,
            workerName: 'Amir Begić',
            daysWorked: 20,
            regularHours: 160,
            overtimeHours: 4,
            totalHours: 164,
          ),
          MonthlyHourReportWorker(
            userId: 2,
            workerName: 'Zlatan Hodžić',
            daysWorked: 18,
            regularHours: 144,
            overtimeHours: 12,
            totalHours: 156,
          ),
        ],
        operations: const [
          MonthlyHourReportOperation(operationName: 'Welding', hours: 200),
          MonthlyHourReportOperation(operationName: 'Assembly', hours: 120),
        ],
      );
}

void _useDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final now = SarajevoTime.now();
  final current = _month(1, now.year, now.month);
  final older = _month(2, 2024, 3, total: 1234.5);

  group('MonthlyReportsProvider', () {
    test('asks for the newest month first, with the count to page by', () async {
      final api = _FakeApi([current, older]);
      final provider = MonthlyReportsProvider(api: api);

      await provider.load();

      expect(api.requests.single['sortBy'], 'Year desc, Month desc');
      expect(api.requests.single['includeTotalCount'], isTrue);
      expect(api.requests.single['year'], isNull);
      expect(provider.months, hasLength(2));
      expect(provider.status, MonthlyReportsStatus.ready);
    });

    test('a year filter goes back to the first page', () async {
      final api = _FakeApi([
        for (var m = 1; m <= 12; m++) _month(m, 2025, m),
        for (var m = 1; m <= 12; m++) _month(100 + m, 2024, m),
      ]);
      final provider = MonthlyReportsProvider(api: api);

      await provider.load();
      expect(provider.pageCount, 2);

      await provider.setPage(2);
      await provider.setYear(2024);

      expect(api.requests.last['year'], 2024);
      expect(api.requests.last['page'], 1);
      expect(provider.pageCount, 1);
    });

    test('only the current Sarajevo month is in progress', () {
      expect(MonthlyReportsProvider.isInProgress(current), isTrue);
      expect(MonthlyReportsProvider.isInProgress(older), isFalse);
    });
  });

  group('who may open it', () {
    test('admins and project managers, nobody else', () {
      expect(AppRoles.canOpen(AppRoles.admin, 'Monthly Reports'), isTrue);
      expect(AppRoles.canOpen(AppRoles.projectManager, 'Monthly Reports'), isTrue);
      expect(AppRoles.canOpen(AppRoles.finances, 'Monthly Reports'), isFalse);
      expect(AppRoles.canOpen(AppRoles.workPreparation, 'Monthly Reports'), isFalse);
    });
  });

  testWidgets('lists the months and opens one', (tester) async {
    _useDesktopSize(tester);
    final api = _FakeApi([current, older]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MonthlyReportsScreen(
          providerFactory: () => MonthlyReportsProvider(api: api),
          detailsBuilder: (provider, report) => MonthlyReportDetailsScreen(
            api: provider.api,
            report: report,
            role: AppRoles.projectManager,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('March 2024'), findsOneWidget);
    expect(find.text('1,234.5 h'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(find.text('March 2024'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly Reports  ›  March 2024'), findsOneWidget);
    expect(find.text('Amir Begić'), findsOneWidget);
    expect(find.text('Welding'), findsOneWidget);
    // The monthly PDF is not a project manager's.
    expect(find.text('Open PDF Report'), findsNothing);
  });

  testWidgets('an admin is sent to Reports with the month, and the workers sort by column',
      (tester) async {
    _useDesktopSize(tester);
    final api = _FakeApi([older]);
    final opened = <DateTime>[];

    await tester.pumpWidget(MaterialApp(
      home: MasterNavigation(
        openMonthlyReport: opened.add,
        child: MonthlyReportDetailsScreen(api: api, report: older, role: AppRoles.admin),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open PDF Report'));
    expect(opened, [DateTime(2024, 3)]);

    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Amir Begić'), lessThan(top('Zlatan Hodžić')));

    // Overtime: biggest first on the first click.
    await tester.tap(find.text('Overtime').last);
    await tester.pumpAndSettle();
    expect(top('Zlatan Hodžić'), lessThan(top('Amir Begić')));

    await tester.tap(find.text('Overtime').last);
    await tester.pumpAndSettle();
    expect(top('Amir Begić'), lessThan(top('Zlatan Hodžić')));
  });
}
