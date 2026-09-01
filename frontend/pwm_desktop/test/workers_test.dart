import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/workers_provider.dart';
import 'package:pwm_desktop/screens/workers_screen.dart';

/// Stands in for one controller, applying the search object it is handed the
/// way the backend would — which is what pins the contract the provider sends.
class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows, {this.matches}) : super('Fake');

  final List<T> rows;

  /// The server-side filter, or null for a table that is read whole.
  final bool Function(T row, Map<String, dynamic> filter)? matches;

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

User _user({
  required int id,
  required String name,
  required String surname,
  required int userTypeId,
  String jobTitle = 'Welder',
  bool isActive = true,
}) =>
    User(
      id: id,
      name: name,
      surname: surname,
      email: '${name.toLowerCase()}.${surname.toLowerCase()}@pwm.ba',
      userTypeId: userTypeId,
      isActive: isActive,
      jobTitle: jobTitle,
      phoneNumber: '+3876110010$id',
    );

/// One administrator, two managers, six active workers and one who has left,
/// in the surname-then-name order the API sorts them by.
final _users = [
  _user(id: 2, name: 'Amar', surname: 'Begic', userTypeId: 2, jobTitle: 'Production manager'),
  _user(id: 3, name: 'Selma', surname: 'Delic', userTypeId: 2, jobTitle: 'Project manager'),
  _user(id: 9, name: 'Lejla', surname: 'Hodzic', userTypeId: 3, jobTitle: 'Quality controller'),
  _user(id: 1, name: 'Nadir', surname: 'Hujdur', userTypeId: 1, jobTitle: 'System administrator'),
  _user(id: 8, name: 'Vedad', surname: 'Imamovic', userTypeId: 3, jobTitle: 'Assembler'),
  _user(id: 4, name: 'Emir', surname: 'Kovacevic', userTypeId: 3),
  _user(id: 6, name: 'Adnan', surname: 'Mujic', userTypeId: 3, jobTitle: 'Locksmith'),
  _user(id: 5, name: 'Damir', surname: 'Softic', userTypeId: 3, jobTitle: 'CNC operator'),
  _user(
      id: 10,
      name: 'Mirza',
      surname: 'Tufekcic',
      userTypeId: 3,
      jobTitle: 'Warehouse operator',
      isActive: false),
  _user(id: 7, name: 'Haris', surname: 'Zulic', userTypeId: 3, jobTitle: 'Painter'),
];

/// What `UserService.ApplyFilters` does with a `UserSearchObject`.
bool _applyUserFilters(User user, Map<String, dynamic> filter) {
  final needle = (filter['search'] as String?)?.toLowerCase();
  if (needle != null) {
    final matches = user.name.toLowerCase().contains(needle) ||
        user.surname.toLowerCase().contains(needle) ||
        user.email.toLowerCase().contains(needle) ||
        (user.jobTitle?.toLowerCase().contains(needle) ?? false);
    if (!matches) return false;
  }

  final userTypeId = filter['userTypeId'] as int?;
  if (userTypeId != null && user.userTypeId != userTypeId) return false;

  final isActive = filter['isActive'] as bool?;
  if (isActive != null && user.isActive != isActive) return false;

  return true;
}

late _FakeProvider<User> _userRows;
late _FakeProvider<UserOperation> _qualificationRows;

WorkersProvider _fakeWorkers() {
  _userRows = _FakeProvider(_users, matches: _applyUserFilters);
  _qualificationRows = _FakeProvider(const [
    UserOperation(id: 1, userId: 4, operationTypeId: 1),
    UserOperation(id: 2, userId: 4, operationTypeId: 2),
    UserOperation(id: 3, userId: 4, operationTypeId: 3),
    UserOperation(id: 4, userId: 5, operationTypeId: 2),
  ]);

  return WorkersProvider(
    users: _userRows,
    userTypes: _FakeProvider(const [
      UserType(id: 1, type: 'Administrator'),
      UserType(id: 2, type: 'Manager'),
      UserType(id: 3, type: 'Worker'),
    ]),
    userOperations: _qualificationRows,
    operationTypes: _FakeProvider(const [
      OperationType(id: 1, name: 'Welding'),
      OperationType(id: 2, name: 'Grinding'),
      OperationType(id: 3, name: 'Assembly'),
    ]),
  );
}

/// The last search object sent for a page of rows, ignoring the count-only
/// calls the counters make.
Map<String, dynamic> _lastPageRequest() => _userRows.requests
    .lastWhere((request) => request['pageSize'] == WorkersProvider.pageSize);

void main() {
  group('WorkersProvider', () {
    late WorkersProvider provider;

    setUp(() async {
      provider = _fakeWorkers();
      await provider.load();
    });

    test('resolves each account to its role name', () {
      expect(provider.status, WorkersStatusState.ready);

      final row = provider.rows.firstWhere((row) => row.id == 4);
      expect(row.fullName, 'Emir Kovacevic');
      expect(row.roleName, 'Worker');
      expect(row.jobTitle, 'Welder');
      expect(row.initials, 'EK');
      // The ids ride along so the details form can prefill.
      expect(row.roleId, 3);
    });

    test('asks the API for one sorted page at a time', () {
      final request = _lastPageRequest();

      expect(request['page'], 1);
      expect(request['pageSize'], WorkersProvider.pageSize);
      expect(request['includeTotalCount'], isTrue);
      expect(request['sortBy'], WorkersProvider.sortBy);
      // Accounts of people who have left are hidden until the funnel says so.
      expect(request['isActive'], isTrue);

      expect(provider.rows.first.fullName, 'Amar Begic');
    });

    test('counts current staff, the shop floor and the office', () {
      // The inactive warehouse operator counts in neither.
      expect(provider.headcount, 10);
      expect(provider.currentCount, 9);
      expect(provider.productionCount, 6);
      expect(provider.administrationCount, 3);
    });

    test('joins the operations a worker is qualified for', () {
      final emir = provider.rows.firstWhere((row) => row.id == 4);
      final selma = provider.rows.firstWhere((row) => row.id == 3);

      expect(emir.operations, ['Assembly', 'Grinding', 'Welding']);
      expect(emir.operationIds, [1, 2, 3]);
      expect(selma.operations, isEmpty);
    });

    test('hides accounts of people who have left until asked', () async {
      expect(provider.rows.any((row) => row.fullName == 'Mirza Tufekcic'), isFalse);

      await provider.setActiveOnly(false);

      expect(_lastPageRequest().containsKey('isActive'), isFalse);
      expect(provider.matchCount, 10);
    });

    test('sends the search box down as the search object', () async {
      await provider.setSearch('kovacevic');
      expect(_lastPageRequest()['search'], 'kovacevic');
      expect(provider.rows.single.id, 4);

      await provider.setSearch('cnc');
      expect(provider.rows.single.fullName, 'Damir Softic');

      await provider.setSearch('selma.delic@pwm.ba');
      expect(provider.rows.single.id, 3);
    });

    test('sends the role filter down as userTypeId', () async {
      await provider.setRole(2);

      expect(_lastPageRequest()['userTypeId'], 2);
      expect(provider.rows.map((row) => row.fullName), ['Amar Begic', 'Selma Delic']);
    });

    test('pages through the API and goes back to page one on a filter', () async {
      expect(provider.pageCount, 2);
      expect(provider.rows.length, WorkersProvider.pageSize);

      await provider.setPage(2);
      expect(provider.page, 2);
      expect(provider.rows.length, 1);

      await provider.setRole(3);
      expect(provider.page, 1);
    });

    test('clears every filter at once', () async {
      await provider.setSearch('emir');
      await provider.setRole(3);
      await provider.setActiveOnly(false);
      expect(provider.hasFilters, isTrue);

      await provider.clearFilters();

      expect(provider.hasFilters, isFalse);
      expect(provider.matchCount, 9);
    });

    test('posts a new account with its password and qualifications', () async {
      await provider.saveWorker(
        name: 'Ivana',
        surname: 'Peric',
        email: 'ivana.peric@pwm.ba',
        userTypeId: 3,
        isActive: true,
        jobTitle: 'Welder',
        password: 'test',
        operationIds: const [1, 3],
      );

      final body = _userRows.inserted.single;
      expect(body['surname'], 'Peric');
      expect(body['userTypeId'], 3);
      expect(body['password'], 'test');

      // The qualifications are rows of their own.
      expect(
        _qualificationRows.inserted.map((row) => row['operationTypeId']),
        containsAll(<int>[1, 3]),
      );
    });

    test('leaves the password out of an update that did not set one', () async {
      await provider.saveWorker(
        id: 3,
        name: 'Selma',
        surname: 'Delic',
        email: 'selma.delic@pwm.ba',
        userTypeId: 2,
        isActive: true,
      );

      final (id, body) = _userRows.updated.single;
      expect(id, 3);
      expect(body.containsKey('password'), isFalse);
      expect(_userRows.inserted, isEmpty);
    });

    test('diffs qualifications rather than rewriting them', () async {
      // Emir holds welding, grinding and assembly; keep two and drop assembly.
      await provider.saveWorker(
        id: 4,
        name: 'Emir',
        surname: 'Kovacevic',
        email: 'emir.kovacevic@pwm.ba',
        userTypeId: 3,
        isActive: true,
        operationIds: const [1, 2],
      );

      expect(_qualificationRows.inserted, isEmpty);
      // Row 3 is the assembly qualification.
      expect(_qualificationRows.removed, [3]);
    });

    test('removes the qualifications before the account they point at', () async {
      await provider.deleteWorker(4);

      expect(_qualificationRows.removed, [1, 2, 3]);
      expect(_userRows.removed, [4]);
    });
  });

  testWidgets('workers screen renders the counters, filters and table', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WorkersScreen(providerFactory: _fakeWorkers)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Workers'), findsOneWidget);
    expect(find.text('Everyone working in the company'), findsOneWidget);
    expect(find.text('All Roles'), findsOneWidget);
    expect(find.text('Add Worker'), findsOneWidget);

    expect(find.text('Current Workers'), findsOneWidget);
    expect(find.text('In Production'), findsOneWidget);
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    expect(find.text('Nadir Hujdur'), findsOneWidget);
    expect(find.text('System administrator'), findsOneWidget);
    expect(find.text('Assembly, Grinding'), findsOneWidget);
    expect(find.text('+1 more'), findsOneWidget);
    // Nine current workers over two pages of eight; the last one by name waits.
    expect(find.text('Haris Zulic'), findsNothing);
  });

  testWidgets('tapping a row opens that account already filled in', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WorkersScreen(providerFactory: _fakeWorkers)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Emir Kovacevic'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
    // Editing keeps the existing password unless one is typed.
    expect(find.text('Leave blank to keep the current one'), findsOneWidget);

    final surname = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Surname',
    ));
    expect(surname.controller?.text, 'Kovacevic');
  });
}
