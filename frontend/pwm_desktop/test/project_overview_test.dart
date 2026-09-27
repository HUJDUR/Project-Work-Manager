import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/project_overview_provider.dart';
import 'package:pwm_desktop/providers/projects_provider.dart';
import 'package:pwm_desktop/screens/project_overview_screen.dart';

/// Stands in for one controller, the same way the other screens' tests do:
/// the fake applies the search object it is handed the way the API would,
/// which is what pins that `ProjectOverviewProvider` actually scopes its two
/// reads to the project it was given rather than reading everything.
class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;

  /// Every search object sent for this table, so a test can check the
  /// project id rode along.
  final List<Map<String, dynamic>> requests = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from((filter as Map?) ?? const {});
    requests.add(query);

    final projectId = query['projectId'] as int?;
    final hits = projectId == null
        ? rows
        : rows.where((row) => (row as dynamic).projectId == projectId).toList();

    return PageResult<T>()..items = hits;
  }

  @override
  Future<T> getById(int id) async => rows.firstWhere((row) => (row as dynamic).id == id);
}

final _today = DateUtils.dateOnly(DateTime.now());

WorkLogDetail _booking({
  required int id,
  required int userId,
  required int operationTypeId,
  required int projectId,
  required DateTime day,
  required double hours,
}) =>
    WorkLogDetail(
      id: id,
      workLogId: id,
      userId: userId,
      operationTypeId: operationTypeId,
      projectId: projectId,
      startedAt: day,
      hours: hours,
    );

TruckLoadDetail _line({
  required int id,
  required int truckLoadId,
  required int projectId,
  required double netoWeight,
}) =>
    TruckLoadDetail(
      id: id,
      truckLoadId: truckLoadId,
      projectId: projectId,
      brutoWeight: netoWeight + 100,
      netoWeight: netoWeight,
      unloadPriority: 1,
      unloadColor: '#000000',
    );

late _FakeProvider<WorkLogDetail> _bookingRows;
late _FakeProvider<TruckLoadDetail> _lineRows;

/// One target project (id 5) with work and cargo of its own, plus a booking
/// and a load line that both belong to a different project (9) - there to
/// prove they get filtered out rather than summed in by mistake.
ProjectOverviewProvider _fakeOverview({int projectId = 5}) => ProjectOverviewProvider(
      projectId: projectId,
      workLogDetails: _bookingRows = _FakeProvider([
        _booking(
            id: 1, userId: 1, operationTypeId: 1, projectId: 5, day: _today, hours: 3),
        _booking(
            id: 2,
            userId: 2,
            operationTypeId: 2,
            projectId: 5,
            day: _today.subtract(const Duration(days: 1)),
            hours: 2),
        _booking(
            id: 3,
            userId: 1,
            operationTypeId: 1,
            projectId: 5,
            day: _today.subtract(const Duration(days: 2)),
            hours: 1.5),
        _booking(
            id: 4, userId: 1, operationTypeId: 1, projectId: 9, day: _today, hours: 99),
      ]),
      users: _FakeProvider(const [
        User(
            id: 1,
            name: 'Ivan',
            surname: 'Ivic',
            email: 'ivan@pwm.ba',
            userTypeId: 3,
            isActive: true),
        User(
            id: 2,
            name: 'Ana',
            surname: 'Anic',
            email: 'ana@pwm.ba',
            userTypeId: 3,
            isActive: true),
      ]),
      operationTypes: _FakeProvider(const [
        OperationType(id: 1, name: 'Welding'),
        OperationType(id: 2, name: 'Cutting'),
      ]),
      truckLoadDetails: _lineRows = _FakeProvider([
        _line(id: 10, truckLoadId: 100, projectId: 5, netoWeight: 800),
        _line(id: 11, truckLoadId: 101, projectId: 5, netoWeight: 450),
        _line(id: 12, truckLoadId: 102, projectId: 9, netoWeight: 700),
      ]),
      truckLoads: _FakeProvider([
        TruckLoad(
          id: 100,
          transportCompanyId: 1,
          truckLoadStatusId: 1,
          loadDate: _today,
          driverName: 'Mario',
          driverSurname: 'Peric',
          vehicleRegistration: 'T-100-AA',
          emptyWeight: 5000,
          fullWeight: 5800,
        ),
        TruckLoad(
          id: 101,
          transportCompanyId: 2,
          truckLoadStatusId: 2,
          loadDate: _today.subtract(const Duration(days: 3)),
          driverName: 'Josip',
          driverSurname: 'Horvat',
          vehicleRegistration: 'T-101-BB',
          emptyWeight: 4000,
          fullWeight: 4450,
        ),
      ]),
      companies: _FakeProvider(const [
        Company(
            id: 1,
            name: 'FastTrans',
            countryId: 1,
            cityId: 1,
            address: 'Cargo 1',
            companyTypeId: 2),
        Company(
            id: 2,
            name: 'HeavyHaul',
            countryId: 1,
            cityId: 1,
            address: 'Cargo 2',
            companyTypeId: 2),
      ]),
      truckLoadStatusTypes: _FakeProvider(const [
        TruckLoadStatusType(id: 1, name: 'In transit'),
        TruckLoadStatusType(id: 2, name: 'Delivered'),
      ]),
    );

/// One project, with the lookups a `ProjectsProvider` needs to join it - the
/// same fixture shape `projects_test.dart` uses.
class _FakePageProvider<T> extends BaseProvider<T> {
  _FakePageProvider(this.rows) : super('Fake');

  final List<T> rows;

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from((filter as Map?) ?? const {});
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

  @override
  Future<T> getById(int id) async => rows.firstWhere((row) => (row as dynamic).id == id);
}

final _project = Project(
  id: 5,
  customerId: 1,
  name: 'Hall roof MU-1',
  code: 'MU-1',
  description: 'A welded hall roof.',
  notes: 'Handle with care.',
  priority: 3,
  createdByUserId: 1,
  weight: 1200,
  projectCategoryId: 1,
  creationDate: _today.subtract(const Duration(days: 30)),
  projectStatusId: 1,
  productionStartDate: _today.subtract(const Duration(days: 20)),
  deliveryDate: _today.add(const Duration(days: 10)),
);

ProjectsProvider _fakeProjects() => ProjectsProvider(
      projects: _FakePageProvider([_project]),
      companies: _FakePageProvider(const [
        Company(
            id: 1,
            name: 'Stahlbau Meyer GmbH',
            countryId: 1,
            cityId: 1,
            address: 'Werkstr. 1',
            companyTypeId: 1),
      ]),
      companyTypes: _FakePageProvider(const [CompanyType(id: 1, name: 'Customer')]),
      categories: _FakePageProvider(const [ProjectCategory(id: 1, name: 'Steel construction')]),
      statusTypes: _FakePageProvider(const [ProjectStatusType(id: 1, name: 'In production')]),
      users: _FakePageProvider(const [
        User(
            id: 1,
            name: 'Nadir',
            surname: 'Hujdur',
            email: 'admin@pwm.ba',
            userTypeId: 1,
            isActive: true),
      ]),
      cities: _FakePageProvider(const [City(id: 1, name: 'Tuzla', postalCode: '75000', countryId: 1)]),
      countries: _FakePageProvider(const [Country(id: 1, name: 'Bosnia and Herzegovina', code: 'BA')]),
    );

void main() {
  group('ProjectOverviewProvider', () {
    late ProjectOverviewProvider provider;

    setUp(() async {
      provider = _fakeOverview();
      await provider.load();
    });

    test('scopes both reads to the project it was given', () {
      expect(_bookingRows.requests.single['projectId'], 5);
      expect(_lineRows.requests.single['projectId'], 5);
    });

    test('resolves work entries to the worker and operation names, newest first', () {
      expect(provider.status, ProjectOverviewStatusState.ready);
      expect(provider.workEntries.map((e) => e.workerName),
          ['Ivan Ivic', 'Ana Anic', 'Ivan Ivic']);
      expect(provider.workEntries.map((e) => e.operationName),
          ['Welding', 'Cutting', 'Welding']);
      expect(provider.workEntries.map((e) => e.hours), [3, 2, 1.5]);
    });

    test('adds hours up per operation, busiest first', () {
      final summary = provider.operationSummary;

      expect(summary.map((s) => s.operationName), ['Welding', 'Cutting']);
      expect(summary.map((s) => s.totalHours), [4.5, 2]);
    });

    test('resolves transport lines to the carrier and status, newest first', () {
      final entries = provider.transportEntries;

      expect(entries.map((e) => e.loadNo), ['TR-0100', 'TR-0101']);
      expect(entries.map((e) => e.carrierName), ['FastTrans', 'HeavyHaul']);
      expect(entries.map((e) => e.statusName), ['In transit', 'Delivered']);
      expect(entries.map((e) => e.weight), [800, 450]);
    });
  });

  testWidgets('the overview page shows the project, its work and its loads',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projects = _fakeProjects();
    await projects.load();
    final row = projects.rows.single;

    await tester.pumpWidget(MaterialApp(
      home: ProjectOverviewScreen(
        provider: projects,
        row: row,
        overviewProviderFactory: (_) => _fakeOverview(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Project Details'), findsOneWidget);
    expect(find.text('Hall roof MU-1'), findsOneWidget);
    expect(find.text('MU-1'), findsOneWidget);
    expect(find.text('Stahlbau Meyer GmbH'), findsOneWidget);
    expect(find.text('Steel construction'), findsOneWidget);

    expect(find.text('Ivan Ivic'), findsWidgets);
    expect(find.text('Welding'), findsWidgets);
    expect(find.text('TR-0100'), findsOneWidget);
    expect(find.text('FastTrans'), findsOneWidget);

    expect(find.widgetWithText(OutlinedButton, 'Edit Project'), findsOneWidget);
  });

  testWidgets('Edit Project opens the project already filled in', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projects = _fakeProjects();
    await projects.load();
    final row = projects.rows.single;

    await tester.pumpWidget(MaterialApp(
      home: ProjectOverviewScreen(
        provider: projects,
        row: row,
        overviewProviderFactory: (_) => _fakeOverview(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Project'));
    await tester.pumpAndSettle();

    expect(find.text('MU-1 - Hall roof MU-1'), findsOneWidget);
    final nameField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Project name',
    ));
    expect(nameField.controller?.text, 'Hall roof MU-1');
  });
}
