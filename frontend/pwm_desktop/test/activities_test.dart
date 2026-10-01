import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/activities_provider.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/screens/activities_screen.dart';
import 'package:pwm_desktop/utils/app_roles.dart';

/// Stands in for one controller, applying the search object it is handed the
/// way the backend would — which is what pins the contract the provider sends.
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

    // The one sort these tests lean on: `Date`, which the API orders by.
    final sorted = [...rows];
    final sortBy = query['sortBy'] as String?;
    if (sortBy != null && sortBy.startsWith('Date')) {
      sorted.sort((a, b) => (a as dynamic).date.compareTo((b as dynamic).date) as int);
      if (sortBy.endsWith('desc')) sorted.setAll(0, sorted.reversed.toList());
    }

    final page = query['page'] as int? ?? 1;
    final pageSize = query['pageSize'] as int? ?? rows.length;
    final start = (page - 1) * pageSize;
    final items = start >= sorted.length
        ? <T>[]
        : sorted.sublist(start, (start + pageSize).clamp(0, sorted.length));

    return PageResult<T>()
      ..items = items
      ..totalCount = (query['includeTotalCount'] as bool? ?? false) ? rows.length : null;
  }
}

User _user({required int id, required String name, required String surname}) => User(
      id: id,
      name: name,
      surname: surname,
      email: '${name.toLowerCase()}.${surname.toLowerCase()}@pwm.ba',
      userTypeId: 1,
      isActive: true,
    );

final _users = [
  _user(id: 1, name: 'Nadir', surname: 'Hujdur'),
  _user(id: 2, name: 'Amar', surname: 'Begic'),
];

const _types = [
  ActivityLogType(id: 1, name: 'Log In'),
  ActivityLogType(id: 2, name: 'Generated report - Monthly Work Hours'),
];

/// Oldest first — the opposite of the order the screen asks the API for, so a
/// test that reads them back newest-first proves it asked for that order.
final _logs = [
  ActivityLog(id: 1, userId: 1, activityLogTypeId: 1, date: DateTime.utc(2026, 9, 20, 8, 5)),
  ActivityLog(
    id: 2,
    userId: 2,
    activityLogTypeId: 2,
    date: DateTime.utc(2026, 9, 21, 14, 30),
    generatedReportId: 7,
  ),
  ActivityLog(id: 3, userId: 1, activityLogTypeId: 1, date: DateTime.utc(2026, 9, 22, 9, 0)),
];

late _FakeProvider<ActivityLog> _logRows;

ActivitiesProvider _fakeActivities() {
  _logRows = _FakeProvider([..._logs]);

  return ActivitiesProvider(
    activityLogs: _logRows,
    activityLogTypes: _FakeProvider(_types),
    users: _FakeProvider(_users),
  );
}

void main() {
  group('ActivitiesProvider', () {
    late ActivitiesProvider provider;

    setUp(() async {
      provider = _fakeActivities();
      await provider.load();
    });

    test('asks the API for the first page, newest first, and names every row', () {
      expect(_logRows.requests.last, {
        'page': 1,
        'pageSize': ActivitiesProvider.pageSize,
        'includeTotalCount': true,
        'sortBy': 'Date desc',
      });
      expect(provider.rows.map((row) => row.userName),
          ['Nadir Hujdur', 'Amar Begic', 'Nadir Hujdur']);
      expect(provider.rows[1].activityTypeName, 'Generated report - Monthly Work Hours');
      expect(provider.rows[0].userInitials, 'NH');
    });

    test('sends the search, activity and whole days to the API', () async {
      await provider.setSearch(' nadir ');
      await provider.setActivityType(1);
      await provider.setDateRange(
          DateTimeRange(start: DateTime(2026, 9, 20, 15), end: DateTime(2026, 9, 22)));

      final query = _logRows.requests.last;
      expect(query['search'], 'nadir');
      expect(query['activityLogTypeId'], 1);
      expect(query['dateFrom'], DateTime(2026, 9, 20));
      expect(query['dateTo'], DateTime(2026, 9, 22, 23, 59, 59, 999));
      expect(provider.hasFilters, isTrue);

      await provider.clearFilters();
      expect(_logRows.requests.last.keys.toSet(),
          {'page', 'pageSize', 'includeTotalCount', 'sortBy'});
    });

    test('a header click sorts on the API, and a filter goes back to page one', () async {
      await provider.setSort('User');
      expect(_logRows.requests.last['sortBy'], 'User');
      await provider.setSort('User');
      expect(_logRows.requests.last['sortBy'], 'User desc');

      await provider.setPage(2);
      expect(_logRows.requests.last['page'], 2);
      await provider.setActivityType(2);
      expect(_logRows.requests.last['page'], 1);
    });

    test('a log against an unknown user or type falls back rather than throwing',
        () async {
      _logRows.rows.add(
        ActivityLog(id: 4, userId: 999, activityLogTypeId: 999, date: DateTime.utc(2026, 9, 23)),
      );

      await provider.setPage(1);
      final orphan = provider.rows.first;

      expect(orphan.userName, 'Unknown user');
      expect(orphan.activityTypeName, 'Unknown activity');
    });
  });

  testWidgets('activities screen renders the filters and the log, newest first',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ActivitiesScreen(providerFactory: _fakeActivities)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('All Activity'), findsOneWidget);
    expect(find.text('Select date range'), findsOneWidget);

    expect(find.text('Nadir Hujdur'), findsNWidgets(2));

    final newest = find.text('22.09.2026.');
    final oldest = find.text('20.09.2026.');
    expect(newest, findsOneWidget);
    expect(oldest, findsOneWidget);
    expect(tester.getTopLeft(newest).dy, lessThan(tester.getTopLeft(oldest).dy));
  });

  group('AppRoles', () {
    test('only an admin may open Activities', () {
      expect(AppRoles.canOpen(AppRoles.admin, 'Activities'), isTrue);
      expect(AppRoles.canOpen(AppRoles.workPreparation, 'Activities'), isFalse);
      expect(AppRoles.canOpen(AppRoles.finances, 'Activities'), isFalse);
      expect(AppRoles.canOpen(AppRoles.projectManager, 'Activities'), isFalse);
    });
  });
}
