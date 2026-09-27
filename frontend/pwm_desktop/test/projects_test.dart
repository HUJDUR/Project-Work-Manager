import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/projects_provider.dart';
import 'package:pwm_desktop/screens/projects_screen.dart';

/// Stands in for one controller. Filtering, sorting and paging belong to the
/// API now, so the fake applies the search object it is handed the way the
/// backend would — which is what pins the contract the provider sends.
class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows, {this.matches}) : super('Fake');

  final List<T> rows;

  /// The server-side filter, or null for a table that is read whole.
  final bool Function(T row, Map<String, dynamic> filter)? matches;

  /// Every search object the provider sent, so a test can read it back.
  final List<Map<String, dynamic>> requests = [];
  final List<Map<String, dynamic>> inserted = [];
  final List<(int, Map<String, dynamic>)> updated = [];
  final List<int> removed = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    final query = Map<String, dynamic>.from((filter as Map?) ?? const {});
    requests.add(query);

    final hits =
        matches == null ? rows : rows.where((row) => matches!(row, query)).toList();

    final page = query['page'] as int? ?? 1;
    final pageSize = query['pageSize'] as int? ?? hits.length;
    final start = (page - 1) * pageSize;
    final items = start >= hits.length
        ? <T>[]
        : hits.sublist(start, (start + pageSize).clamp(0, hits.length));

    return PageResult<T>()
      ..items = items
      ..totalCount = (query['includeTotalCount'] as bool? ?? false) ? hits.length : null;
  }

  @override
  Future<T> insert(dynamic request) async {
    inserted.add(Map<String, dynamic>.from(request as Map));
    return rows.first;
  }

  @override
  Future<T> update(int id, [dynamic request]) async {
    updated.add((id, Map<String, dynamic>.from(request as Map)));
    return rows.first;
  }

  @override
  Future remove(int id) async => removed.add(id);
}

final _today = DateUtils.dateOnly(DateTime.now());

Project _project({
  required int id,
  required String name,
  required int customerId,
  required int statusId,
  required String code,
  int categoryId = 1,
  double weight = 1000,
  int createdDaysAgo = 0,
  int priority = 2,
  int createdByUserId = 1,
  int? deliveryCompanyId,
}) =>
    Project(
      id: id,
      customerId: customerId,
      name: name,
      code: code,
      description: 'Seeded fixture project.',
      notes: null,
      priority: priority,
      createdByUserId: createdByUserId,
      weight: weight,
      projectCategoryId: categoryId,
      creationDate: _today.subtract(Duration(days: createdDaysAgo)),
      projectStatusId: statusId,
      productionStartDate: _today.subtract(Duration(days: createdDaysAgo)),
      deliveryDate: _today.add(const Duration(days: 10)),
      deliveryCompanyId: deliveryCompanyId,
    );

const _companies = [
  Company(
      id: 1,
      name: 'Stahlbau Meyer GmbH',
      countryId: 1,
      cityId: 1,
      address: 'Werkstr. 1',
      companyTypeId: 1),
  Company(
      id: 2,
      name: 'Nordmetall AG',
      countryId: 1,
      cityId: 1,
      address: 'Hafenweg 2',
      companyTypeId: 1),
  Company(
      id: 3,
      name: 'TransBalkan Logistika',
      countryId: 1,
      cityId: 1,
      address: 'Put 3',
      companyTypeId: 2),
];

/// Ten projects, newest first as the API sorts them, so the eight-row page size
/// leaves a second page.
final _projects = [
  _project(
      id: 1,
      name: 'Hall roof MU-1',
      code: 'MU-1',
      customerId: 1,
      statusId: 3,
      createdDaysAgo: 1,
      priority: 4,
      createdByUserId: 2,
      deliveryCompanyId: 3),
  _project(id: 2, name: 'Railing MU-2', code: 'MU-2', customerId: 1, statusId: 3, createdDaysAgo: 2),
  _project(code: 'AK-3', id: 3, name: 'Silo AK-3', customerId: 2, statusId: 5, createdDaysAgo: 3),
  _project(code: 'NM-4', id: 4, name: 'Frame NM-4', customerId: 2, statusId: 6, createdDaysAgo: 4),
  _project(code: 'AS-5', id: 5, name: 'Panels AS-5', customerId: 1, statusId: 1, createdDaysAgo: 5),
  _project(code: 'NM-6', id: 6, name: 'Brackets NM-6', customerId: 2, statusId: 1, createdDaysAgo: 6),
  _project(code: 'WM-7', id: 7, name: 'Stairs WM-7', customerId: 1, statusId: 1, createdDaysAgo: 7),
  _project(code: 'AK-8', id: 8, name: 'Plates AK-8', customerId: 2, statusId: 3, createdDaysAgo: 8),
  _project(code: 'MU-9', id: 9, name: 'Beams MU-9', customerId: 1, statusId: 5, createdDaysAgo: 9),
  _project(code: 'AS-10', id: 10, name: 'Covers AS-10', customerId: 2, statusId: 5, createdDaysAgo: 10),
];

/// What `ProjectService.ApplyFilters` does with a `ProjectSearchObject`.
bool _applyProjectFilters(Project project, Map<String, dynamic> filter) {
  final needle = (filter['search'] as String?)?.toLowerCase();
  if (needle != null) {
    final customer =
        _companies.where((company) => company.id == project.customerId).firstOrNull;
    final matchesName = project.name.toLowerCase().contains(needle);
    final matchesCustomer =
        customer != null && customer.name.toLowerCase().contains(needle);
    if (!matchesName && !matchesCustomer) return false;
  }

  final statusId = filter['projectStatusId'] as int?;
  if (statusId != null && project.projectStatusId != statusId) return false;

  return true;
}

late _FakeProvider<Project> _projectRows;

ProjectsProvider _fakeProjects() {
  _projectRows = _FakeProvider(_projects, matches: _applyProjectFilters);

  return ProjectsProvider(
    projects: _projectRows,
    companies: _FakeProvider(_companies),
    users: _FakeProvider(const [
      User(
          id: 1,
          name: 'Nadir',
          surname: 'Hujdur',
          email: 'admin@pwm.ba',
          userTypeId: 1,
          isActive: true),
      User(
          id: 2,
          name: 'Selma',
          surname: 'Delic',
          email: 'selma@pwm.ba',
          userTypeId: 2,
          isActive: true),
    ]),
    cities: _FakeProvider(const [
      City(id: 1, name: 'Tuzla', postalCode: '75000', countryId: 1),
    ]),
    countries: _FakeProvider(const [
      Country(id: 1, name: 'Bosnia and Herzegovina', code: 'BA'),
    ]),
    companyTypes: _FakeProvider(const [
      CompanyType(id: 1, name: 'Customer'),
      CompanyType(id: 2, name: 'Transport'),
    ]),
    categories: _FakeProvider(const [
      ProjectCategory(id: 1, name: 'Steel construction'),
      ProjectCategory(id: 2, name: 'Sheet metal parts'),
    ]),
    statusTypes: _FakeProvider(const [
      ProjectStatusType(id: 1, name: 'On hold'),
      ProjectStatusType(id: 3, name: 'In production'),
      ProjectStatusType(id: 5, name: 'Delivered'),
      ProjectStatusType(id: 6, name: 'Rejected'),
    ]),
  );
}

/// The last search object sent for a page of rows, ignoring the count-only
/// calls the counters make.
Map<String, dynamic> _lastPageRequest() => _projectRows.requests
    .lastWhere((request) => request['pageSize'] == ProjectsProvider.pageSize);

void main() {
  group('ProjectsProvider', () {
    late ProjectsProvider provider;

    setUp(() async {
      provider = _fakeProjects();
      await provider.load();
    });

    test('joins each project to its customer, category and status', () {
      expect(provider.status, ProjectsStatusState.ready);

      final row = provider.rows.firstWhere((row) => row.id == 1);
      expect(row.name, 'Hall roof MU-1');
      expect(row.customerName, 'Stahlbau Meyer GmbH');
      expect(row.categoryName, 'Steel construction');
      expect(row.statusName, 'In production');
      // The ids ride along so the details form can prefill.
      expect(row.customerId, 1);
      expect(row.categoryId, 1);
      expect(row.statusId, 3);
    });

    test('resolves the project detail fields the mockup asks for', () {
      final row = provider.rows.firstWhere((row) => row.id == 1);

      expect(row.code, 'MU-1');
      expect(row.displayName, 'MU-1 - Hall roof MU-1');
      expect(row.priority, ProjectPriority.veryHigh);
      expect(row.createdByUserId, 2);
      expect(row.createdByName, 'Selma Delic');
      // Location is the delivery company's city and country, two joins away.
      expect(row.deliveryCompanyId, 3);
      expect(row.location, 'Tuzla, Bosnia and Herzegovina');
    });

    test('leaves location empty until a carrier is assigned', () {
      final row = provider.rows.firstWhere((row) => row.id == 2);

      expect(row.deliveryCompanyId, isNull);
      expect(row.location, isNull);
      // Nothing was set, so the project sits at the default priority.
      expect(row.priority, ProjectPriority.medium);
    });

    test('asks the API for one sorted page at a time', () {
      final request = _lastPageRequest();

      expect(request['page'], 1);
      expect(request['pageSize'], ProjectsProvider.pageSize);
      expect(request['includeTotalCount'], isTrue);
      expect(request['sortBy'], ProjectsProvider.sortBy);

      expect(provider.rows.length, ProjectsProvider.pageSize);
      expect(provider.rows.first.name, 'Hall roof MU-1');
    });

    test('counts active, in production and delivered over every project', () {
      // Delivered (3) and Rejected (1) are not active.
      expect(provider.totalCount, 10);
      expect(provider.activeCount, 6);
      expect(provider.inProductionCount, 3);
      expect(provider.deliveredCount, 3);
    });

    test('sends the search box down as the search object', () async {
      await provider.setSearch('mu-');

      expect(_lastPageRequest()['search'], 'mu-');
      expect(provider.rows.map((row) => row.id), [1, 2, 9]);

      await provider.setSearch('nordmetall');
      expect(provider.rows.every((row) => row.customerName == 'Nordmetall AG'), isTrue);
    });

    test('sends the status filter down as projectStatusId', () async {
      await provider.setStatus(3);

      expect(_lastPageRequest()['projectStatusId'], 3);
      expect(provider.rows.map((row) => row.name),
          ['Hall roof MU-1', 'Railing MU-2', 'Plates AK-8']);
    });

    test('pages through the API and goes back to page one on a filter', () async {
      expect(provider.pageCount, 2);

      await provider.setPage(2);
      expect(provider.page, 2);
      expect(_lastPageRequest()['page'], 2);
      expect(provider.rows.map((row) => row.name), ['Beams MU-9', 'Covers AS-10']);

      await provider.setStatus(5);
      expect(provider.page, 1);
      expect(provider.pageCount, 1);
    });

    test('refuses a page outside the range', () async {
      await provider.setPage(9);

      expect(provider.page, provider.pageCount);
    });

    test('clears every filter at once', () async {
      await provider.setSearch('silo');
      await provider.setStatus(5);
      expect(provider.hasFilters, isTrue);

      await provider.clearFilters();

      expect(provider.hasFilters, isFalse);
      expect(provider.matchCount, 10);
      expect(_lastPageRequest().containsKey('search'), isFalse);
      expect(_lastPageRequest().containsKey('projectStatusId'), isFalse);
    });

    test('offers only customer companies for a new project', () {
      expect(provider.customers.map((company) => company.name),
          ['Nordmetall AG', 'Stahlbau Meyer GmbH']);
    });

    test('posts a new project with the dates the API insists on', () async {
      await provider.saveProject(
        name: 'Frame TB-1',
        code: 'TB-1',
        description: 'A welded frame.',
        customerId: 2,
        projectCategoryId: 1,
        projectStatusId: 1,
        createdByUserId: 2,
        priority: ProjectPriority.high,
        weight: 1250.5,
        creationDate: DateTime(2026, 8, 29),
        productionStartDate: DateTime(2026, 8, 30),
      );

      final body = _projectRows.inserted.single;
      expect(body['name'], 'Frame TB-1');
      expect(body['code'], 'TB-1');
      expect(body['description'], 'A welded frame.');
      expect(body['customerId'], 2);
      expect(body['weight'], 1250.5);
      // The enum goes over the wire as the int the column stores.
      expect(body['priority'], ProjectPriority.high.value);
      expect(body['createdByUserId'], 2);
      expect(body['productionStartDate'], '2026-08-30T00:00:00.000');
      // Nullable in the schema, and the API accepts it missing.
      expect(body['deliveryDate'], isNull);
      // NOT NULL in the schema, so the client has to supply it.
      expect(body['creationDate'], '2026-08-29T00:00:00.000');
      expect(_projectRows.updated, isEmpty);
    });

    test('puts an existing project back rather than posting a second one',
        () async {
      await provider.saveProject(
        id: 7,
        name: 'Stairs WM-7',
        code: 'WM-7',
        customerId: 1,
        projectCategoryId: 2,
        projectStatusId: 5,
        createdByUserId: 1,
        priority: ProjectPriority.low,
        weight: 900,
        creationDate: DateTime(2026, 8, 20),
        productionStartDate: DateTime(2026, 8, 21),
        deliveryCompanyId: 3,
        deliveryDate: DateTime(2026, 9, 15),
      );

      final (id, body) = _projectRows.updated.single;
      expect(id, 7);
      expect(body['projectStatusId'], 5);
      expect(body['deliveryCompanyId'], 3);
      expect(body['deliveryDate'], '2026-09-15T00:00:00.000');
      expect(_projectRows.inserted, isEmpty);
    });

    test('deletes a project by id', () async {
      await provider.deleteProject(4);

      expect(_projectRows.removed, [4]);
    });
  });

  testWidgets('projects screen renders the counters, filters and table', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProjectsScreen(providerFactory: _fakeProjects)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Overview of all projects'), findsOneWidget);
    expect(find.text('Add Project'), findsOneWidget);
    expect(find.text('All Status'), findsOneWidget);

    expect(find.text('Active Projects'), findsOneWidget);
    expect(find.text('In Production'), findsOneWidget);
    expect(find.text('Delivered'), findsWidgets);

    expect(find.text('Hall roof MU-1'), findsOneWidget);
    expect(find.text('Stahlbau Meyer GmbH'), findsWidgets);
    // Page one holds eight of the ten projects.
    expect(find.text('Beams MU-9'), findsNothing);
  });

  testWidgets('Add Project opens a blank form with the fields the API needs',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProjectsScreen(providerFactory: _fakeProjects)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Project'));
    await tester.pumpAndSettle();

    expect(find.text('New Project'), findsOneWidget);
    expect(find.text('Project name'), findsOneWidget);
    expect(find.text('Customer'), findsWidgets);
    expect(find.text('Category'), findsWidgets);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Production start'), findsOneWidget);
    expect(find.text('Delivery date'), findsOneWidget);
    expect(find.text('Project code'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Priority'), findsWidgets);
    expect(find.text('Created by'), findsOneWidget);
    expect(find.text('Delivery company'), findsWidgets);
    expect(find.text('Notes'), findsOneWidget);
    // The code box opens on the next number in this year's run rather than
    // empty; the fixture holds no code in that shape, so it starts the year.
    final codeField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Project code',
    ));
    final prefix = (DateTime.now().year % 100).toString().padLeft(2, '0');
    expect(codeField.controller?.text, '$prefix-001');

    // Adding cannot delete, and an empty form refuses to save.
    expect(find.text('Delete'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('A project needs a name.'), findsOneWidget);
    expect(_projectRows.inserted, isEmpty);
  });

  testWidgets('tapping a row opens its read-only overview', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProjectsScreen(providerFactory: _fakeProjects)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hall roof MU-1'));
    await tester.pumpAndSettle();

    // The mockup's static title, not the project's own name.
    expect(find.text('Project Details'), findsOneWidget);
    expect(find.text('Hall roof MU-1'), findsWidgets);
    expect(find.text('MU-1'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Edit Project'), findsOneWidget);
  });

  testWidgets('Edit Project opens that project already filled in', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProjectsScreen(providerFactory: _fakeProjects)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hall roof MU-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Project'));
    await tester.pumpAndSettle();

    // The title is the project by the name the shop uses for it.
    expect(find.text('MU-1 - Hall roof MU-1'), findsOneWidget);
    // The title is the project, and an existing project can be deleted.
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);

    final nameField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Project name',
    ));
    expect(nameField.controller?.text, 'Hall roof MU-1');
  });

  group('the next project code', () {
    /// The provider's own rule, restated so the test does not depend on the
    /// year the suite happens to run in.
    String prefix() =>
        (DateTime.now().year % 100).toString().padLeft(2, '0');

    ProjectsProvider providerOver(List<Project> rows) => ProjectsProvider(
          projects: _FakeProvider(rows, matches: _applyProjectFilters),
          companies: _FakeProvider(_companies),
          companyTypes: _FakeProvider(const [
            CompanyType(id: 1, name: 'Customer'),
            CompanyType(id: 2, name: 'Transport'),
          ]),
          categories: _FakeProvider(const [ProjectCategory(id: 1, name: 'Sections')]),
          statusTypes: _FakeProvider(const [
            ProjectStatusType(id: 3, name: 'In production'),
          ]),
          users: _FakeProvider(const <User>[]),
          cities: _FakeProvider(const <City>[]),
          countries: _FakeProvider(const <Country>[]),
        );

    Project coded(int id, String code) =>
        _project(id: id, name: 'P$id', code: code, customerId: 1, statusId: 3, createdDaysAgo: id);

    test('carries on from the highest number this year', () async {
      final provider = providerOver([
        coded(1, '${prefix()}-002'),
        coded(2, '${prefix()}-005'),
        coded(3, '${prefix()}-001'),
      ]);
      await provider.load();

      expect(provider.nextCode, '${prefix()}-006');
    });

    test('starts the year at 001 when nothing carries this year', () async {
      // Last year's run, and a code from before the scheme existed.
      final lastYear = ((DateTime.now().year - 1) % 100).toString().padLeft(2, '0');
      final provider = providerOver([
        coded(1, '$lastYear-042'),
        coded(2, 'MU-2201'),
      ]);
      await provider.load();

      expect(provider.nextCode, '${prefix()}-001');
    });

    test('an empty book starts at 001', () async {
      final provider = providerOver(const []);
      await provider.load();

      expect(provider.nextCode, '${prefix()}-001');
    });

    test('a new project opens with it, an existing one keeps its own', () async {
      final provider = providerOver([coded(1, '${prefix()}-004')]);
      await provider.load();

      expect(provider.nextCode, '${prefix()}-005');
      expect(provider.rows.single.code, '${prefix()}-004');
    });
  });
}
