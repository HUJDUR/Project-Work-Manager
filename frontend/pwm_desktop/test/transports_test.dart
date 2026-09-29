import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/auth_provider.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/transports_provider.dart';
import 'package:pwm_desktop/providers/truck_load_provider.dart';
import 'package:pwm_desktop/screens/transport_overview_screen.dart';
import 'package:pwm_desktop/screens/transport_screen.dart';
import 'package:pwm_desktop/utils/app_roles.dart';
import 'package:pwm_desktop/utils/sarajevo_time.dart';

/// The status panel reads `AuthProvider` - every screen test that can reach
/// it needs it in the tree, the same way `project_overview_test.dart`
/// already provides it.
Widget _wrapped(Widget child) => ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(home: child),
    );

/// Stands in for one controller. Filtering, sorting and paging belong to the
/// API, so the fake applies the search object it is handed the way the backend
/// would — which is what pins the contract the provider sends.
class _FakeProvider<T> extends BaseProvider<T> {
  @override
  T fromJson(dynamic data) => throw UnimplementedError();

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

  @override
  Future<T> getById(int id) async => rows.firstWhere((row) => (row as dynamic).id == id);
}

/// The `truckLoads:` fake, wrapping a `_FakeProvider<TruckLoad>` for the
/// plain CRUD it already knows how to fake, and adding the status-change
/// endpoints `TruckLoadProvider` carries beyond a bare `BaseProvider`.
class _FakeTruckLoadProvider extends TruckLoadProvider {
  _FakeTruckLoadProvider(this._inner);

  final _FakeProvider<TruckLoad> _inner;

  /// Every status-change call, so a test can read back what was asked for.
  final List<(int id, int statusId, double? price)> statusChanges = [];

  List<Map<String, dynamic>> get requests => _inner.requests;
  List<Map<String, dynamic>> get inserted => _inner.inserted;
  List<(int, Map<String, dynamic>)> get updated => _inner.updated;
  List<int> get removed => _inner.removed;

  @override
  Future<PageResult<TruckLoad>> get({dynamic filter}) => _inner.get(filter: filter);

  @override
  Future<TruckLoad> getById(int id) => _inner.getById(id);

  @override
  Future<TruckLoad> insert(dynamic request) => _inner.insert(request);

  @override
  Future<TruckLoad> update(int id, [dynamic request]) => _inner.update(id, request);

  @override
  Future remove(int id) => _inner.remove(id);

  @override
  Future<TruckLoad> changeStatus(int id, int newStatusId, {double? price}) async {
    statusChanges.add((id, newStatusId, price));
    return _inner.getById(id);
  }

  @override
  Future<List<TruckLoadStatusChangeEntry>> statusHistory(int id) async => [
        TruckLoadStatusChangeEntry(
          id: 1,
          toStatusName: 'Ordered',
          changedByName: 'Nadir Hujdur',
          changedAt: DateTime.utc(2026, 8, 30, 7),
        ),
      ];
}

DateTime _day(int daysAgo) =>
    DateUtils.dateOnly(DateTime.now()).subtract(Duration(days: daysAgo));

TruckLoad _load({
  required int id,
  required int carrierId,
  required int statusId,
  required String driverName,
  required String driverSurname,
  required String registration,
  int daysAgo = 0,
  double emptyWeight = 14000,
  double fullWeight = 26000,
}) =>
    TruckLoad(
      id: id,
      transportCompanyId: carrierId,
      truckLoadStatusId: statusId,
      loadDate: _day(daysAgo),
      driverName: driverName,
      driverSurname: driverSurname,
      vehicleRegistration: registration,
      emptyWeight: emptyWeight,
      fullWeight: fullWeight,
      note: null,
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
      name: 'TransBalkan Logistika',
      countryId: 1,
      cityId: 1,
      address: 'Put 3',
      companyTypeId: 2),
  Company(
      id: 3,
      name: 'Euro Spedicija',
      countryId: 1,
      cityId: 1,
      address: 'Put 7',
      companyTypeId: 2),
];

/// Ten loads, most recent first as the API sorts them, so the eight-row page
/// size leaves a second page.
final _loads = [
  _load(
      id: 1,
      carrierId: 2,
      statusId: 4,
      driverName: 'Senad',
      driverSurname: 'Alispahic',
      registration: 'A12-K-345',
      daysAgo: 1,
      emptyWeight: 14200,
      fullWeight: 26650.5),
  _load(
      id: 2,
      carrierId: 3,
      statusId: 2,
      driverName: 'Ivica',
      driverSurname: 'Maric',
      registration: 'ZG-4417-BK',
      daysAgo: 2),
  _load(
      id: 3,
      carrierId: 2,
      statusId: 1,
      driverName: 'Mladen',
      driverSurname: 'Peric',
      registration: 'T88-J-902',
      daysAgo: 3),
  _load(
      id: 4,
      carrierId: 3,
      statusId: 2,
      driverName: 'Fahrudin',
      driverSurname: 'Salkic',
      registration: 'E31-M-119',
      daysAgo: 4),
  _load(
      id: 5,
      carrierId: 2,
      statusId: 2,
      driverName: 'Damir',
      driverSurname: 'Kovac',
      registration: 'K10-A-771',
      daysAgo: 5),
  _load(
      id: 6,
      carrierId: 3,
      statusId: 3,
      driverName: 'Emir',
      driverSurname: 'Begic',
      registration: 'M55-B-204',
      daysAgo: 6),
  _load(
      id: 7,
      carrierId: 2,
      statusId: 4,
      driverName: 'Josip',
      driverSurname: 'Lukic',
      registration: 'O21-C-880',
      daysAgo: 7),
  _load(
      id: 8,
      carrierId: 3,
      statusId: 2,
      driverName: 'Nedim',
      driverSurname: 'Hodzic',
      registration: 'J77-D-345',
      daysAgo: 8),
  _load(
      id: 9,
      carrierId: 2,
      statusId: 3,
      driverName: 'Vlado',
      driverSurname: 'Simic',
      registration: 'B04-E-512',
      daysAgo: 9),
  _load(
      id: 10,
      carrierId: 3,
      statusId: 1,
      driverName: 'Adnan',
      driverSurname: 'Music',
      registration: 'S66-F-193',
      daysAgo: 10),
];

const _details = [
  TruckLoadDetail(
      id: 1,
      truckLoadId: 1,
      projectId: 2,
      brutoWeight: 980.25,
      netoWeight: 962,
      unloadPriority: 2,
      unloadColor: 'Orange'),
  TruckLoadDetail(
      id: 2,
      truckLoadId: 1,
      projectId: 1,
      brutoWeight: 12450.5,
      netoWeight: 12300,
      unloadPriority: 1,
      unloadColor: 'Red'),
  TruckLoadDetail(
      id: 3,
      truckLoadId: 2,
      // Not "In production" - off the cargo dropdown, but still on this load.
      projectId: 3,
      brutoWeight: 3820,
      netoWeight: 3760.5,
      unloadPriority: 1,
      unloadColor: 'Blue'),
];

Project _project({
  required int id,
  required String name,
  required String code,
  int statusId = 3,
}) =>
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
      creationDate: _day(20),
      projectStatusId: statusId,
      productionStartDate: _day(20),
      deliveryDate: null,
      deliveryCompanyId: null,
    );

final _projects = [
  _project(id: 1, name: 'Hall roof structure', code: 'MU-2201'),
  _project(id: 2, name: 'Cladding panels', code: 'AK-2202'),
  // Not "In production" - a cargo dropdown should skip it, but an existing
  // load referencing it (see `_details`) still needs its name resolved.
  _project(id: 3, name: 'Storage racks', code: 'AK-2203', statusId: 5),
];

/// What `TruckLoadService.ApplyFilters` does with a `TruckLoadSearchObject`.
bool _applyLoadFilters(TruckLoad load, Map<String, dynamic> filter) {
  final needle = (filter['search'] as String?)?.toLowerCase();
  if (needle != null) {
    final carrier =
        _companies.where((company) => company.id == load.transportCompanyId).firstOrNull;
    final hit = load.driverName.toLowerCase().contains(needle) ||
        load.driverSurname.toLowerCase().contains(needle) ||
        load.vehicleRegistration.toLowerCase().contains(needle) ||
        (carrier != null && carrier.name.toLowerCase().contains(needle));
    if (!hit) return false;
  }

  final statusId = filter['truckLoadStatusId'] as int?;
  if (statusId != null && load.truckLoadStatusId != statusId) return false;

  final from = filter['dateFrom'] as String?;
  if (from != null && load.loadDate.isBefore(SarajevoTime.fromApi(from))) return false;

  final to = filter['dateTo'] as String?;
  if (to != null && load.loadDate.isAfter(SarajevoTime.fromApi(to))) return false;

  return true;
}

bool _applyDetailFilters(TruckLoadDetail detail, Map<String, dynamic> filter) {
  final truckLoadId = filter['truckLoadId'] as int?;
  return truckLoadId == null || detail.truckLoadId == truckLoadId;
}

late _FakeProvider<TruckLoad> _loadRowsInner;
late _FakeTruckLoadProvider _loadRows;
late _FakeProvider<TruckLoadDetail> _detailRows;

TransportsProvider _fakeTransports() {
  _loadRowsInner = _FakeProvider(_loads, matches: _applyLoadFilters);
  _loadRows = _FakeTruckLoadProvider(_loadRowsInner);
  _detailRows = _FakeProvider(_details, matches: _applyDetailFilters);

  return TransportsProvider(
    truckLoads: _loadRows,
    truckLoadDetails: _detailRows,
    companies: _FakeProvider(_companies),
    companyTypes: _FakeProvider(const [
      CompanyType(id: 1, name: 'Customer'),
      CompanyType(id: 2, name: 'Transport'),
    ]),
    statusTypes: _FakeProvider(const [
      TruckLoadStatusType(id: 1, name: 'Ordered'),
      TruckLoadStatusType(id: 2, name: 'Delivered'),
      TruckLoadStatusType(id: 3, name: 'Finished'),
      TruckLoadStatusType(id: 4, name: 'Rejected'),
    ]),
    projects: _FakeProvider(_projects),
    projectStatusTypes: _FakeProvider(const [
      ProjectStatusType(id: 3, name: 'In production'),
      ProjectStatusType(id: 5, name: 'On hold'),
    ]),
  );
}

/// The last search object sent for a page of rows.
Map<String, dynamic> _lastPageRequest() => _loadRows.requests
    .lastWhere((request) => request['pageSize'] == TransportsProvider.pageSize);

void main() {
  setUp(() {
    AuthProvider.user = const User(
      id: 1,
      name: 'Nadir',
      surname: 'Hujdur',
      email: 'admin@pwm.ba',
      userTypeId: 1,
      isActive: true,
    );
    AuthProvider.role = 'Admin';
  });

  tearDown(() {
    AuthProvider.user = null;
    AuthProvider.role = '';
  });

  group('TransportsProvider', () {
    late TransportsProvider provider;

    setUp(() async {
      provider = _fakeTransports();
      await provider.load();
    });

    test('joins each load to its carrier and status', () {
      expect(provider.status, TransportsStatusState.ready);

      final row = provider.rows.firstWhere((row) => row.id == 1);
      expect(row.carrierName, 'TransBalkan Logistika');
      expect(row.statusName, 'Rejected');
      expect(row.driverFullName, 'Senad Alispahic');
      expect(row.vehicleRegistration, 'A12-K-345');
      // The ids ride along so the details form can prefill.
      expect(row.carrierId, 2);
      expect(row.statusId, 4);
    });

    test('numbers a load by its id and weighs its cargo', () {
      final row = provider.rows.firstWhere((row) => row.id == 1);

      // There is no transport-number column; this is the id, written out.
      expect(row.transportNo, 'TR-0001');
      expect(row.netWeight, 12450.5);
    });

    test('asks the API for one sorted page at a time', () {
      final request = _lastPageRequest();

      expect(request['page'], 1);
      expect(request['pageSize'], TransportsProvider.pageSize);
      expect(request['includeTotalCount'], isTrue);
      expect(request['sortBy'], TransportsProvider.sortBy);

      expect(provider.rows.length, TransportsProvider.pageSize);
      expect(provider.matchCount, 10);
    });

    test('sends the search box down as the search object', () async {
      await provider.setSearch('maric');

      expect(_lastPageRequest()['search'], 'maric');
      expect(provider.rows.map((row) => row.id), [2]);

      // The carrier and the registration are searchable too.
      await provider.setSearch('euro spedicija');
      expect(provider.rows.map((row) => row.id), [2, 4, 6, 8, 10]);

      await provider.setSearch('T88-J');
      expect(provider.rows.map((row) => row.id), [3]);
    });

    test('sends the status filter down as truckLoadStatusId', () async {
      await provider.setStatus(2);

      expect(_lastPageRequest()['truckLoadStatusId'], 2);
      expect(provider.rows.map((row) => row.id), [2, 4, 5, 8]);
    });

    test('closes the date range on the last second of its final day', () async {
      // A load dated three days ago carries no time of day here, but a real one
      // would - so the range has to run past midnight to include it.
      await provider.setDateRange(
        DateTimeRange(start: _day(3), end: _day(2)),
      );

      final request = _lastPageRequest();
      expect(SarajevoTime.fromApi(request['dateFrom'] as String), _day(3));
      expect(
        SarajevoTime.fromApi(request['dateTo'] as String),
        _day(2).add(const Duration(hours: 23, minutes: 59, seconds: 59)),
      );
      expect(provider.rows.map((row) => row.id), [2, 3]);
    });

    test('pages through the API and goes back to page one on a filter', () async {
      expect(provider.pageCount, 2);

      await provider.setPage(2);
      expect(provider.page, 2);
      expect(_lastPageRequest()['page'], 2);
      expect(provider.rows.map((row) => row.id), [9, 10]);

      await provider.setStatus(1);
      expect(provider.page, 1);
      expect(provider.pageCount, 1);
    });

    test('clears every filter at once', () async {
      await provider.setSearch('maric');
      await provider.setStatus(2);
      await provider.setDateRange(DateTimeRange(start: _day(5), end: _day(1)));
      expect(provider.hasFilters, isTrue);

      await provider.clearFilters();

      expect(provider.hasFilters, isFalse);
      expect(provider.matchCount, 10);
      final request = _lastPageRequest();
      expect(request.containsKey('search'), isFalse);
      expect(request.containsKey('truckLoadStatusId'), isFalse);
      expect(request.containsKey('dateFrom'), isFalse);
    });

    test('offers every company that is not a customer as a carrier', () {
      expect(provider.carriers.map((company) => company.name),
          ['Euro Spedicija', 'TransBalkan Logistika']);
    });

    test('only offers a project on the cargo list while it is in production',
        () async {
      expect(provider.projects.map((project) => project.name),
          ['Cladding panels', 'Hall roof structure']);

      // Dropped from the cargo list, but a load that already carries it still
      // needs its name.
      final lines = await provider.linesOf(2);
      expect(lines.single.projectName, 'Storage racks');
    });

    test('reads one load cargo in unload order', () async {
      final lines = await provider.linesOf(1);

      expect(_detailRows.requests.last['truckLoadId'], 1);
      expect(lines.map((line) => line.unloadPriority), [1, 2]);
      expect(lines.first.projectName, 'Hall roof structure');
      expect(lines.first.unloadColor, 'Red');
      expect(lines.every((line) => line.isNew), isFalse);
    });

    test('posts a new load and hangs its cargo off the id that comes back',
        () async {
      await provider.saveTransport(
        transportCompanyId: 2,
        loadDate: DateTime(2026, 9, 1),
        driverName: 'Senad',
        driverSurname: 'Alispahic',
        vehicleRegistration: 'A12-K-345',
        emptyWeight: 14200,
        fullWeight: 26650.5,
        note: 'Wide load.',
        lines: const [
          TransportLine(
            id: 0,
            projectId: 1,
            projectName: 'Hall roof structure',
            brutoWeight: 12450.5,
            netoWeight: 12300,
            unloadPriority: 1,
            unloadColor: 'Red',
          ),
        ],
      );

      final body = _loadRows.inserted.single;
      expect(body['transportCompanyId'], 2);
      expect(body.containsKey('truckLoadStatusId'), isFalse);
      // Sarajevo midnight, sent as the UTC instant it names (CEST, UTC+2).
      expect(body['loadDate'], '2026-08-31T22:00:00.000Z');
      expect(body['vehicleRegistration'], 'A12-K-345');
      expect(body['fullWeight'], 26650.5);
      expect(body['note'], 'Wide load.');
      expect(_loadRows.updated, isEmpty);

      // A line with no row behind it is inserted against the new load's id.
      final line = _detailRows.inserted.single;
      expect(line['truckLoadId'], _loads.first.id);
      expect(line['projectId'], 1);
      expect(line['unloadPriority'], 1);
      expect(_detailRows.updated, isEmpty);
      expect(_detailRows.removed, isEmpty);
    });

    test('diffs the cargo when an existing load is put back', () async {
      final original = await provider.linesOf(1);

      await provider.saveTransport(
        id: 1,
        transportCompanyId: 3,
        loadDate: DateTime(2026, 9, 1),
        driverName: 'Senad',
        driverSurname: 'Alispahic',
        vehicleRegistration: 'A12-K-345',
        emptyWeight: 14200,
        fullWeight: 26650.5,
        lines: [
          // Kept, with a heavier load than before.
          original.first.copyWith(netoWeight: 12500),
          const TransportLine(
            id: 0,
            projectId: 2,
            projectName: 'Cladding panels',
            brutoWeight: 500,
            netoWeight: 480,
            unloadPriority: 3,
            unloadColor: 'Green',
          ),
        ],
        originalLines: original,
      );

      final (id, body) = _loadRows.updated.single;
      expect(id, 1);
      expect(body.containsKey('truckLoadStatusId'), isFalse);
      expect(_loadRows.inserted, isEmpty);

      // The kept line is put back, the new one inserted, the dropped one gone.
      expect(_detailRows.updated.single.$1, original.first.id);
      expect(_detailRows.updated.single.$2['netoWeight'], 12500);
      expect(_detailRows.inserted.single['projectId'], 2);
      expect(_detailRows.removed, [original.last.id]);
    });

    test('deletes a load and lets the cargo cascade with it', () async {
      await provider.deleteTransport(4);

      expect(_loadRows.removed, [4]);
      expect(_detailRows.removed, isEmpty);
    });
  });

  testWidgets('transport screen renders the header, filters and table',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TransportScreen(providerFactory: _fakeTransports)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Transport Overview'), findsOneWidget);
    expect(find.text('Overview of all transport operations'), findsOneWidget);
    expect(find.text('Add Transport'), findsOneWidget);
    expect(find.text('All Status'), findsOneWidget);
    expect(find.text('Select date range'), findsOneWidget);

    for (final column in const [
      'Transport No',
      'Load Date',
      'Driver Name',
      'Driver Surname',
      'Registration',
      'Full Weight (kg)',
      'Empty Weight (kg)',
    ]) {
      expect(find.text(column), findsOneWidget);
    }

    expect(find.text('TR-0001'), findsOneWidget);
    expect(find.text('Alispahic'), findsOneWidget);
    // Page one holds eight of the ten loads.
    expect(find.text('TR-0010'), findsNothing);
  });

  testWidgets('the search box clears in one tap', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TransportScreen(providerFactory: _fakeTransports)),
    ));
    await tester.pumpAndSettle();

    final searchField = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.hintText == 'Search transports...');

    // Nothing to clear yet.
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(searchField, 'maric');
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
    expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);

    // The clear searched immediately - not just queued behind the debounce.
    await tester.pump(const Duration(milliseconds: 350));
    expect(_lastPageRequest().containsKey('search'), isFalse);
  });

  testWidgets('Add Transport opens a blank form with the fields the API needs',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TransportScreen(providerFactory: _fakeTransports)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Transport'));
    await tester.pumpAndSettle();

    expect(find.text('New Transport'), findsOneWidget);
    expect(find.text('Carrier'), findsWidgets);
    expect(find.text('Driver name'), findsOneWidget);
    expect(find.text('Driver surname'), findsOneWidget);
    expect(find.text('Registration'), findsOneWidget);
    expect(find.text('Load date'), findsOneWidget);
    expect(find.text('Empty weight'), findsOneWidget);
    expect(find.text('Full weight'), findsOneWidget);
    // Cargo is never shown while making a new transport - the load has to
    // be saved once before anything can be loaded onto it.
    expect(find.text('Cargo'), findsNothing);
    expect(find.text('Nothing loaded yet.'), findsNothing);
    // Adding cannot delete, and an empty form refuses to save.
    expect(find.text('Delete'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('The driver needs a name.'), findsOneWidget);
    expect(_loadRows.inserted, isEmpty);
  });

  testWidgets(
      'tapping a row opens the transport overview with its cargo already on it',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapped(
      Scaffold(body: TransportScreen(providerFactory: _fakeTransports)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TR-0001'));
    await tester.pumpAndSettle();

    // The overview reads, it does not edit - the cargo is fetched for the
    // load that was opened, not for the page.
    expect(find.text('Transport Details'), findsOneWidget);
    expect(find.text('Senad Alispahic'), findsOneWidget);
    expect(find.text('Hall roof structure'), findsOneWidget);
    expect(find.text('Cladding panels'), findsOneWidget);

    // "Edit Transport" is the only way into the edit form - and TR-0001 is
    // Rejected, so it opens locked to everything but its notes.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Transport'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
    expect(
      find.textContaining('only its notes can be saved from here'),
      findsOneWidget,
    );

    final driverField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Driver name',
    ));
    expect(driverField.controller?.text, 'Senad');
    expect(driverField.enabled, isFalse);
  });

  testWidgets(
      'a cargo line flags neto above bruto only once the field is left, not while typing',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapped(
      Scaffold(body: TransportScreen(providerFactory: _fakeTransports)),
    ));
    await tester.pumpAndSettle();

    // TR-0003 is still Ordered - cargo can only be added while it is.
    await tester.tap(find.text('TR-0003'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Transport'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add cargo'));
    await tester.pumpAndSettle();

    Finder fieldLabelled(String label) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == label);

    await tester.enterText(fieldLabelled('Bruto weight'), '2500');
    await tester.enterText(fieldLabelled('Neto weight'), '5000');
    await tester.pump();

    // Still being typed into - no verdict while it is still focused.
    expect(find.textContaining('Cannot be above'), findsNothing);

    // Tabbing to the next field is what leaves it, and triggers the check.
    await tester.tap(fieldLabelled('Unload order'));
    await tester.pump();

    expect(find.text('Cannot be above the bruto weight.'), findsOneWidget);
  });

  testWidgets('the project field on a cargo line can be searched by its code',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapped(
      Scaffold(body: TransportScreen(providerFactory: _fakeTransports)),
    ));
    await tester.pumpAndSettle();

    // TR-0003 is still Ordered - cargo can only be added while it is.
    await tester.tap(find.text('TR-0003'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Transport'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add cargo'));
    await tester.pumpAndSettle();

    // Scoped to the dialog: the screen underneath has its own "Load date"
    // TextField, which a bare `find.byType(TextField)` would hit first.
    final projectField = find
        .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
        .first;

    // Both projects' names are unrelated words - only their codes tie them
    // together, so finding one by typing the other's code proves the search
    // matches the code, not just the name.
    await tester.tap(projectField);
    await tester.pumpAndSettle();
    await tester.enterText(projectField, 'AK-2202');
    await tester.pumpAndSettle();

    expect(find.text('AK-2202 - Cladding panels'), findsOneWidget);

    await tester.tap(find.text('AK-2202 - Cladding panels').last);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(projectField).controller?.text,
        'AK-2202 - Cladding panels');
  });

  testWidgets(
      'an admin sees only the legal next statuses, and picking one calls the API',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = _fakeTransports();
    await provider.load();
    final row = provider.rows.firstWhere((r) => r.id == 3); // Ordered

    await tester.pumpWidget(_wrapped(
      TransportOverviewScreen(provider: provider, row: row),
    ));
    await tester.pumpAndSettle();

    // Ordered can move to Delivered or Rejected - never straight to Finished.
    expect(find.widgetWithText(OutlinedButton, 'Mark delivered'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Finish transport'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Move TR-0003 from "Ordered" to "Rejected"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Move to Rejected'));
    await tester.pumpAndSettle();

    expect(_loadRows.statusChanges.single, (3, 4, null));
  });

  testWidgets('finishing a transport asks for the invoice amount first',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = _fakeTransports();
    await provider.load();
    final row = provider.rows.firstWhere((r) => r.id == 2); // Delivered

    await tester.pumpWidget(_wrapped(
      TransportOverviewScreen(provider: provider, row: row),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Finish transport'));
    await tester.pumpAndSettle();

    final amountField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Invoice amount',
    );
    expect(amountField, findsOneWidget);

    // An empty amount refuses to close the popup - Finished always needs one.
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    expect(_loadRows.statusChanges, isEmpty);

    await tester.enterText(amountField, '1850.50');
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();

    expect(_loadRows.statusChanges.single, (2, 3, 1850.5));
  });

  testWidgets(
      'a production worker sees the status but cannot change it',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    AuthProvider.role = AppRoles.productionWorker;

    final provider = _fakeTransports();
    await provider.load();
    final row = provider.rows.firstWhere((r) => r.id == 3); // Ordered

    await tester.pumpWidget(_wrapped(
      TransportOverviewScreen(provider: provider, row: row),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Mark delivered'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNothing);
    expect(
      find.text('Only an administrator or project manager can change this'),
      findsOneWidget,
    );
  });
}
