import 'package:flutter/material.dart';
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

/// Oldest first — the opposite of the order the table should default to
/// showing them in, so a test that reads them back newest-first proves the
/// table is doing its own sorting rather than just echoing the fetch.
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
  _logRows = _FakeProvider(_logs);

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

    test('resolves the user and activity type on every row, newest first', () async {
      final rows = await provider.loadAllRows();

      expect(_logRows.requests.last['sortBy'], 'Date desc');
      expect(rows.map((row) => row.userName), ['Nadir Hujdur', 'Amar Begic', 'Nadir Hujdur']);
      expect(rows[1].activityTypeName, 'Generated report - Monthly Work Hours');
      expect(rows[0].userInitials, 'NH');
    });

    test('a log against an unknown user or type falls back rather than throwing',
        () async {
      _logRows.rows.add(
        ActivityLog(id: 4, userId: 999, activityLogTypeId: 999, date: DateTime.utc(2026, 9, 23)),
      );

      final rows = await provider.loadAllRows();
      final orphan = rows.last;

      expect(orphan.userName, 'Unknown user');
      expect(orphan.activityTypeName, 'Unknown activity');
    });
  });

  testWidgets('activities screen renders the log with no filters, newest first',
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

    // No dropdowns and no "clear filters" - the column headers are the only
    // filter this screen offers.
    expect(find.text('All Users'), findsNothing);
    expect(find.text('All Activity'), findsNothing);
    expect(find.text('Clear filters'), findsNothing);

    // Log 3 (22 Sep) sits above log 1 (20 Sep) despite the fixtures listing
    // log 1 first - the table's own default sort, not fetch order.
    final rows = tester
        .widgetList<Text>(find.text('Nadir Hujdur'))
        .map((text) => text.data)
        .toList();
    expect(rows, hasLength(2));

    final newest = find.text('22.09.2026.');
    final oldest = find.text('20.09.2026.');
    expect(newest, findsOneWidget);
    expect(oldest, findsOneWidget);
    expect(
      tester.getTopLeft(newest).dy,
      lessThan(tester.getTopLeft(oldest).dy),
    );
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
