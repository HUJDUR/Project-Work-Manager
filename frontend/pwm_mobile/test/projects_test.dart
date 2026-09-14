import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/base_provider.dart';
import 'package:pwm_mobile/providers/projects_provider.dart';
import 'package:pwm_mobile/screens/projects_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';

/// Pages its rows the way the API does, so a test can see what the screen asked
/// for and what it did with the answer.
class _PagedProvider<T> extends BaseProvider<T> {
  _PagedProvider(this.rows) : super('Fake');

  final List<T> rows;
  final List<Map<String, dynamic>> filters = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    final map = Map<String, dynamic>.from(filter as Map);
    filters.add(map);

    final matching = _matching(map);
    final page = (map['page'] as int?) ?? 1;
    final size = (map['pageSize'] as int?) ?? matching.length;
    final start = (page - 1) * size;

    return PageResult<T>()
      ..totalCount = matching.length
      ..items = matching.skip(start).take(size).toList();
  }

  /// Only what the real service filters on, so a test cannot pass by filtering
  /// client-side something the API would not have narrowed.
  List<T> _matching(Map<String, dynamic> filter) {
    final statusId = filter['projectStatusId'] as int?;
    final search = (filter['search'] as String?)?.toLowerCase();

    return rows.where((row) {
      final project = row as dynamic;
      if (statusId != null && project.projectStatusId != statusId) return false;
      if (search != null &&
          !'${project.code} ${project.name}'.toLowerCase().contains(search)) {
        return false;
      }
      return true;
    }).toList();
  }
}

class _ListProvider<T> extends BaseProvider<T> {
  _ListProvider(this.rows) : super('Fake');

  final List<T> rows;
  final List<dynamic> filters = [];

  @override
  Future<PageResult<T>> get({dynamic filter}) async {
    filters.add(filter);
    return PageResult<T>()..items = rows;
  }
}

class _FailingProvider<T> extends BaseProvider<T> {
  _FailingProvider() : super('Fake');

  @override
  Future<PageResult<T>> get({dynamic filter}) async =>
      throw ApiClientException('The API is unreachable.');
}

final _now = DateTime(2026, 9, 14);

Project _project({
  required int id,
  required String code,
  required String name,
  int statusId = 2,
  int categoryId = 8,
  double weight = 12400,
  DateTime? deliveryDate,
  int? deliveryCompanyId = 2,
}) =>
    Project(
      id: id,
      customerId: 1,
      name: name,
      code: code,
      weight: weight,
      projectCategoryId: categoryId,
      creationDate: _now,
      projectStatusId: statusId,
      deliveryDate: deliveryDate,
      deliveryCompanyId: deliveryCompanyId,
      createdByUserId: 1,
    );

/// Ten in production plus one delivered. The delivered one is here precisely
/// so a test can show it never reaches the list.
List<Project> _projects() => [
      for (var i = 1; i <= 10; i++)
        _project(
          id: i,
          code: '26-0${i.toString().padLeft(2, '0')}',
          name: 'Project $i',
          deliveryDate: DateTime(2026, 9, 27),
        ),
      _project(
        id: 99,
        code: '26-003',
        name: 'Hall roof structure',
        statusId: 1,
        categoryId: 1,
        deliveryDate: DateTime(2026, 8, 27),
      ),
    ];

List<ProjectStatusType> _statuses() => const [
      ProjectStatusType(id: 1, name: 'Delivered'),
      ProjectStatusType(id: 2, name: 'In production'),
      ProjectStatusType(id: 3, name: 'On hold'),
    ];

List<ProjectCategory> _categories() => const [
      ProjectCategory(id: 1, name: 'Sections'),
      ProjectCategory(id: 8, name: 'General steel construction'),
    ];

List<Company> _companies() => const [
      // 1 is the customer — never shown. 2 is where the job is delivered.
      Company(
        id: 1,
        name: 'Adria Konstrukcije d.o.o.',
        cityId: 9,
        address: 'Slavonska avenija 45',
        companyTypeId: 2,
      ),
      Company(
        id: 2,
        name: 'Meyer Baustelle Nord',
        cityId: 9,
        address: 'Billbrookdeich 210',
        companyTypeId: 3,
      ),
    ];

List<City> _cities() => const [
      City(id: 9, name: 'Zagreb', postalCode: '10000', countryId: 4),
    ];

List<Country> _countries() => const [
      Country(id: 4, name: 'Croatia', code: 'HR'),
    ];

WorkLogDetail _block({
  required int id,
  required int projectId,
  required DateTime startedAt,
  double hours = 2,
}) =>
    WorkLogDetail(
      id: id,
      workLogId: 1,
      userId: 20,
      operationTypeId: 9,
      projectId: projectId,
      startedAt: startedAt,
      hours: hours,
    );

({
  ProjectsProvider provider,
  _PagedProvider<Project> projects,
  _ListProvider<WorkLogDetail> blocks,
}) _build({List<WorkLogDetail> workBlocks = const []}) {
  final projects = _PagedProvider<Project>(_projects());
  final blocks = _ListProvider<WorkLogDetail>(workBlocks);

  return (
    provider: ProjectsProvider(
      projects: projects,
      statuses: _ListProvider<ProjectStatusType>(_statuses()),
      categories: _ListProvider<ProjectCategory>(_categories()),
      companies: _ListProvider<Company>(_companies()),
      cities: _ListProvider<City>(_cities()),
      countries: _ListProvider<Country>(_countries()),
      workLogDetails: blocks,
      userId: 20,
    ),
    projects: projects,
    blocks: blocks,
  );
}

ProjectsProvider _providerOver(BaseProvider<Project> projects) => ProjectsProvider(
      projects: projects,
      statuses: _ListProvider<ProjectStatusType>(_statuses()),
      categories: _ListProvider<ProjectCategory>(_categories()),
      companies: _ListProvider<Company>(_companies()),
      cities: _ListProvider<City>(_cities()),
      countries: _ListProvider<Country>(_countries()),
      workLogDetails: _ListProvider<WorkLogDetail>(const []),
      userId: 20,
    );

void main() {
  group('the list', () {
    test('asks the API for one page and names the rows from the lookups',
        () async {
      final fixture = _build();
      await fixture.provider.load();

      expect(fixture.provider.status, ProjectsStatus.ready);
      expect(fixture.provider.rows.length, ProjectsProvider.pageSize);
      // Ten in production; the delivered one is not counted.
      expect(fixture.provider.totalCount, 10);

      final first = fixture.provider.rows.first;
      expect(first.displayName, '26-001 - Project 1');
      expect(first.statusName, 'In production');
      expect(first.categoryName, 'General steel construction');

      final sent = fixture.projects.filters.single;
      expect(sent['projectStatusId'], 2, reason: 'In production, always');
      expect(sent['page'], 1);
      expect(sent['pageSize'], ProjectsProvider.pageSize);
      expect(sent['includeTotalCount'], true);
      expect(sent['sortBy'], 'CreationDate desc');
    });

    test('load more appends the next page rather than replacing it', () async {
      final fixture = _build();
      await fixture.provider.load();

      expect(fixture.provider.hasMore, isTrue);
      await fixture.provider.loadMore();

      expect(fixture.provider.rows.length, 10);
      expect(fixture.projects.filters.last['page'], 2);
      // The first page is still there, in order.
      expect(fixture.provider.rows.first.displayName, '26-001 - Project 1');
      expect(fixture.provider.hasMore, isFalse);
    });

    test('load more does nothing once everything is shown', () async {
      final fixture = _build();
      await fixture.provider.load();
      await fixture.provider.loadMore();

      final calls = fixture.projects.filters.length;
      await fixture.provider.loadMore();

      expect(fixture.projects.filters.length, calls);
    });

    test('every page asks for in production, never anything else', () async {
      final fixture = _build();
      await fixture.provider.load();
      await fixture.provider.loadMore();
      await fixture.provider.applySearch('Project');

      expect(fixture.projects.filters, isNotEmpty);
      for (final sent in fixture.projects.filters) {
        expect(sent['projectStatusId'], 2);
      }
      expect(
        fixture.provider.rows.every((row) => row.statusName == 'In production'),
        isTrue,
      );
    });

    test('a delivered project is not listed, even when the search names it',
        () async {
      final fixture = _build();
      await fixture.provider.load();

      await fixture.provider.applySearch('Hall roof');

      // It exists and the search matches it — the status is what excludes it.
      expect(fixture.provider.rows, isEmpty);
      expect(fixture.provider.isEmpty, isTrue);
    });

    test('nothing is listed when no status is called "In production"',
        () async {
      // A database seeded without it: showing everything would be worse than
      // showing nothing, because every row would be one a worker cannot act on.
      final projects = _PagedProvider<Project>(_projects());
      final provider = ProjectsProvider(
        projects: projects,
        statuses: _ListProvider<ProjectStatusType>(
          const [ProjectStatusType(id: 1, name: 'Delivered')],
        ),
        categories: _ListProvider<ProjectCategory>(_categories()),
        companies: _ListProvider<Company>(_companies()),
        cities: _ListProvider<City>(_cities()),
        countries: _ListProvider<Country>(_countries()),
        workLogDetails: _ListProvider<WorkLogDetail>(const []),
        userId: 20,
      );
      await provider.load();

      expect(provider.status, ProjectsStatus.ready);
      expect(provider.rows, isEmpty);
      expect(provider.hasMore, isFalse);
      expect(projects.filters, isEmpty, reason: 'nothing worth asking for');
    });

    test('the search goes to the API, and clearing it comes back', () async {
      final fixture = _build();
      await fixture.provider.load();

      await fixture.provider.applySearch('  Project 1  ');
      expect(fixture.projects.filters.last['search'], 'Project 1');
      // "Project 1" and "Project 10", both in production.
      expect(fixture.provider.rows.length, 2);

      await fixture.provider.applySearch('');
      // An empty search is left out of the request entirely.
      expect(fixture.projects.filters.last.containsKey('search'), isFalse);
      expect(fixture.provider.rows.length, ProjectsProvider.pageSize);
    });

    test('the lookups are read once, not per page', () async {
      final fixture = _build();
      final statuses = _ListProvider<ProjectStatusType>(_statuses());
      final provider = ProjectsProvider(
        projects: fixture.projects,
        statuses: statuses,
        categories: _ListProvider<ProjectCategory>(_categories()),
        companies: _ListProvider<Company>(_companies()),
        cities: _ListProvider<City>(_cities()),
        countries: _ListProvider<Country>(_countries()),
        workLogDetails: _ListProvider<WorkLogDetail>(const []),
        userId: 20,
      );

      await provider.load();
      await provider.loadMore();
      await provider.applySearch('Project');

      expect(statuses.filters.length, 1);
    });

    test('a failed load keeps the API wording', () async {
      final provider = ProjectsProvider(
        projects: _FailingProvider<Project>(),
        statuses: _ListProvider<ProjectStatusType>(_statuses()),
        categories: _ListProvider<ProjectCategory>(_categories()),
        companies: _ListProvider<Company>(_companies()),
        cities: _ListProvider<City>(_cities()),
        countries: _ListProvider<Country>(_countries()),
        workLogDetails: _ListProvider<WorkLogDetail>(const []),
        userId: 20,
      );
      await provider.load();

      expect(provider.status, ProjectsStatus.failed);
      expect(provider.errorMessage, 'The API is unreachable.');
    });
  });

  group('the delivery destination', () {
    test('is the delivery company, with its address on one line', () async {
      final fixture = _build();
      await fixture.provider.load();

      final place = fixture.provider.deliveryOf(fixture.provider.rows.first)!;
      expect(place.name, 'Meyer Baustelle Nord');
      expect(place.address, 'Billbrookdeich 210, 10000 Zagreb, Croatia');
    });

    test('is never the customer', () async {
      final fixture = _build();
      await fixture.provider.load();

      final place = fixture.provider.deliveryOf(fixture.provider.rows.first)!;
      // The customer is company 1; the shop floor is not shown who ordered it.
      expect(place.name, isNot('Adria Konstrukcije d.o.o.'));
      expect(place.address, isNot(contains('Slavonska avenija')));
    });

    test('is null when the project has no delivery company', () async {
      final projects = _PagedProvider<Project>([
        _project(
          id: 1,
          code: '26-001',
          name: 'Project 1',
          deliveryCompanyId: null,
        ),
      ]);
      final provider = _providerOver(projects);
      await provider.load();

      expect(provider.deliveryOf(provider.rows.single), isNull);
    });

    test('leaves out the parts the lookups cannot resolve', () async {
      // No city row, so no town and no country — the street still stands.
      final provider = ProjectsProvider(
        projects: _PagedProvider<Project>(_projects()),
        statuses: _ListProvider<ProjectStatusType>(_statuses()),
        categories: _ListProvider<ProjectCategory>(_categories()),
        companies: _ListProvider<Company>(_companies()),
        cities: _ListProvider<City>(const []),
        countries: _ListProvider<Country>(const []),
        workLogDetails: _ListProvider<WorkLogDetail>(const []),
        userId: 20,
      );
      await provider.load();

      expect(
        provider.deliveryOf(provider.rows.first)!.address,
        'Billbrookdeich 210',
      );
    });
  });

  group('your work on a project', () {
    test('totals the hours and counts the distinct days', () async {
      final fixture = _build(workBlocks: [
        _block(id: 1, projectId: 3, startedAt: DateTime(2026, 9, 7, 7), hours: 4),
        _block(id: 2, projectId: 3, startedAt: DateTime(2026, 9, 7, 12), hours: 2),
        _block(id: 3, projectId: 3, startedAt: DateTime(2026, 9, 8, 8), hours: 3),
      ]);
      await fixture.provider.load();

      final work = await fixture.provider.workOn(3);

      expect(work.hours, 9);
      // Two bookings on the Monday are one day worked.
      expect(work.days, 2);
      expect(work.lastWorked, DateTime(2026, 9, 8, 8));
    });

    test('is asked for by worker AND project, not filtered in Dart', () async {
      final fixture = _build(workBlocks: [
        _block(id: 1, projectId: 3, startedAt: DateTime(2026, 9, 7, 7)),
      ]);
      await fixture.provider.load();
      await fixture.provider.workOn(3);

      // `getAll` adds its own paging keys, so the narrowing is what matters.
      final sent = fixture.blocks.filters.single as Map;
      expect(sent['userId'], 20);
      expect(sent['projectId'], 3);
    });

    test('a project never worked on reads as empty', () async {
      final fixture = _build();
      await fixture.provider.load();

      final work = await fixture.provider.workOn(3);

      expect(work.isEmpty, isTrue);
      expect(work.lastWorked, isNull);
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester, ProjectsProvider provider) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProjectsScreen(providerFactory: () => provider)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lays out as the mockup does', (tester) async {
      await pump(tester, _build().provider);

      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Projects currently in production'), findsOneWidget);
      expect(find.text('Search projects'), findsOneWidget);
      // No status filter and no status chip: every row is in production.
      expect(find.text('All'), findsNothing);
      expect(find.text('In production'), findsNothing);
      expect(find.text('8 of 10 projects'), findsOneWidget);
      expect(find.text('26-001 - Project 1'), findsOneWidget);

      // Eight cards put it below the fold on a phone, so scroll to it. The
      // scrollable has to be named: the status chips are a second one.
      await tester.scrollUntilVisible(
        find.text('Load more'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Load more'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a search that only a delivered project matches says so',
        (tester) async {
      final fixture = _build();
      await pump(tester, fixture.provider);

      await fixture.provider.applySearch('Hall roof');
      await tester.pumpAndSettle();

      expect(find.text('No projects match'), findsOneWidget);
      expect(find.text('Only projects in production are listed.'),
          findsOneWidget);
      expect(find.text('26-003 - Hall roof structure'), findsNothing);
    });

    testWidgets('load more is gone once everything is shown', (tester) async {
      final fixture = _build();
      await pump(tester, fixture.provider);

      // Dragged to the end of the scroll extent rather than scrolled just far
      // enough: a button sitting half under the fold is not reliably tappable.
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(fixture.provider.rows.length, 10);

      // Down to the end of the longer list: there is nothing left to fetch.
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Load more'), findsNothing);

      // And the count at the top now says the whole book.
      await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(find.text('10 projects'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      await pump(
        tester,
        ProjectsProvider(
          projects: _FailingProvider<Project>(),
          statuses: _ListProvider<ProjectStatusType>(_statuses()),
          categories: _ListProvider<ProjectCategory>(_categories()),
          companies: _ListProvider<Company>(_companies()),
          cities: _ListProvider<City>(_cities()),
          countries: _ListProvider<Country>(_countries()),
          workLogDetails: _ListProvider<WorkLogDetail>(const []),
          userId: 20,
        ),
      );

      expect(find.text('The API is unreachable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
