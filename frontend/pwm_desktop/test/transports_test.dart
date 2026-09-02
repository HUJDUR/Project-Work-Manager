import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/transports_provider.dart';
import 'package:pwm_desktop/screens/transport_screen.dart';

/// Stands in for one controller. Filtering, sorting and paging belong to the
/// API, so the fake applies the search object it is handed the way the backend
/// would — which is what pins the contract the provider sends.
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
      id: 1, name: 'Stahlbau Meyer GmbH', cityId: 1, address: 'Werkstr. 1', companyTypeId: 1),
  Company(
      id: 2,
      name: 'TransBalkan Logistika',
      cityId: 1,
      address: 'Put 3',
      companyTypeId: 2),
  Company(id: 3, name: 'Euro Spedicija', cityId: 1, address: 'Put 7', companyTypeId: 2),
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
      statusId: 5,
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
      statusId: 5,
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
      statusId: 5,
      driverName: 'Nedim',
      driverSurname: 'Hodzic',
      registration: 'J77-D-345',
      daysAgo: 8),
  _load(
      id: 9,
      carrierId: 2,
      statusId: 6,
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
      projectId: 1,
      brutoWeight: 3820,
      netoWeight: 3760.5,
      unloadPriority: 1,
      unloadColor: 'Blue'),
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
      creationDate: _day(20),
      projectStatusId: 3,
      productionStartDate: _day(20),
      deliveryDate: null,
      deliveryCompanyId: null,
    );

final _projects = [
  _project(id: 1, name: 'Hall roof structure', code: 'MU-2201'),
  _project(id: 2, name: 'Cladding panels', code: 'AK-2202'),
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
  if (from != null && load.loadDate.isBefore(DateTime.parse(from))) return false;

  final to = filter['dateTo'] as String?;
  if (to != null && load.loadDate.isAfter(DateTime.parse(to))) return false;

  return true;
}

bool _applyDetailFilters(TruckLoadDetail detail, Map<String, dynamic> filter) {
  final truckLoadId = filter['truckLoadId'] as int?;
  return truckLoadId == null || detail.truckLoadId == truckLoadId;
}

late _FakeProvider<TruckLoad> _loadRows;
late _FakeProvider<TruckLoadDetail> _detailRows;

TransportsProvider _fakeTransports() {
  _loadRows = _FakeProvider(_loads, matches: _applyLoadFilters);
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
      TruckLoadStatusType(id: 1, name: 'Planned'),
      TruckLoadStatusType(id: 2, name: 'Loading'),
      TruckLoadStatusType(id: 3, name: 'Loaded'),
      TruckLoadStatusType(id: 4, name: 'In transit'),
      TruckLoadStatusType(id: 5, name: 'Delivered'),
      TruckLoadStatusType(id: 6, name: 'Cancelled'),
    ]),
    projects: _FakeProvider(_projects),
  );
}

/// The last search object sent for a page of rows.
Map<String, dynamic> _lastPageRequest() => _loadRows.requests
    .lastWhere((request) => request['pageSize'] == TransportsProvider.pageSize);

void main() {
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
      expect(row.statusName, 'In transit');
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
      await provider.setStatus(5);

      expect(_lastPageRequest()['truckLoadStatusId'], 5);
      expect(provider.rows.map((row) => row.id), [2, 4, 8]);
    });

    test('closes the date range on the last second of its final day', () async {
      // A load dated three days ago carries no time of day here, but a real one
      // would - so the range has to run past midnight to include it.
      await provider.setDateRange(
        DateTimeRange(start: _day(3), end: _day(2)),
      );

      final request = _lastPageRequest();
      expect(DateTime.parse(request['dateFrom'] as String), _day(3));
      expect(
        DateTime.parse(request['dateTo'] as String),
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
      await provider.setStatus(5);
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
        truckLoadStatusId: 1,
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
      expect(body['truckLoadStatusId'], 1);
      expect(body['loadDate'], '2026-09-01T00:00:00.000');
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
        truckLoadStatusId: 5,
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
      expect(body['truckLoadStatusId'], 5);
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
    expect(find.text('Cargo'), findsOneWidget);
    expect(find.text('Nothing loaded yet.'), findsOneWidget);
    // Adding cannot delete, and an empty form refuses to save.
    expect(find.text('Delete'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('The driver needs a name.'), findsOneWidget);
    expect(_loadRows.inserted, isEmpty);
  });

  testWidgets('tapping a row opens that load with its cargo already on it',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TransportScreen(providerFactory: _fakeTransports)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TR-0001'));
    await tester.pumpAndSettle();

    // The title is the load, and an existing load can be deleted.
    expect(find.text('TR-0001'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);

    final driverField = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Driver name',
    ));
    expect(driverField.controller?.text, 'Senad');

    // The cargo is fetched for the load that was opened, not for the page.
    expect(find.text('Hall roof structure'), findsOneWidget);
    expect(find.text('Cladding panels'), findsOneWidget);
  });
}
