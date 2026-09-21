import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/notification_provider.dart';
import 'package:pwm_desktop/providers/notifications_provider.dart';
import 'package:pwm_desktop/screens/notifications_screen.dart';
import 'package:pwm_desktop/utils/api_client_exception.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows, {this.matches}) : super('Fake');

  final List<T> rows;

  /// The server-side filter, or null for a table that is read whole.
  final bool Function(T row, Map<String, dynamic> filter)? matches;

  final List<Map<String, dynamic>> requests = [];

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
}

/// `POST /Notification/Send`, which is the only way into the table.
class _FakeNotificationProvider extends NotificationProvider {
  final List<Map<String, dynamic>> sent = [];

  /// Set to make the next send fail the way the API would.
  Object? failure;

  @override
  Future<int> sendNotification({
    required String title,
    required String message,
    List<int>? userIds,
  }) async {
    sent.add({'title': title, 'message': message, 'userIds': userIds});
    if (failure case final error?) throw error;

    return userIds?.length ?? _activeUsers.length;
  }
}

const _activeUsers = [
  User(
      id: 4,
      name: 'Vedran',
      surname: 'Alagic',
      email: 'vedran@pwm.ba',
      userTypeId: 3,
      isActive: true),
  User(
      id: 2,
      name: 'Selma',
      surname: 'Delic',
      email: 'selma@pwm.ba',
      userTypeId: 2,
      isActive: true),
  User(
      id: 3,
      name: 'Emir',
      surname: 'Kovacevic',
      email: 'emir@pwm.ba',
      userTypeId: 3,
      isActive: true),
];

const _closedUser = User(
    id: 9,
    name: 'Damir',
    surname: 'Softic',
    email: 'damir@pwm.ba',
    userTypeId: 3,
    isActive: false);

/// What `UserService.ApplyFilters` does with the `isActive` the screen sends.
bool _applyUserFilters(User user, Map<String, dynamic> filter) {
  final isActive = filter['isActive'] as bool?;
  return isActive == null || user.isActive == isActive;
}

late _FakeNotificationProvider _notifications;
late _FakeProvider<User> _userRows;

NotificationsProvider _fakeNotifications() {
  _notifications = _FakeNotificationProvider();
  _userRows = _FakeProvider([..._activeUsers, _closedUser], matches: _applyUserFilters);

  return NotificationsProvider(
    notifications: _notifications,
    users: _userRows,
    userTypes: _FakeProvider(const [
      UserType(id: 1, type: 'Admin'),
      UserType(id: 2, type: 'Project manager'),
      UserType(id: 3, type: 'Production worker'),
    ]),
  );
}

void main() {
  group('NotificationsProvider', () {
    late NotificationsProvider provider;

    setUp(() async {
      provider = _fakeNotifications();
      await provider.load();
    });

    test('asks the API for the accounts that still work, already sorted', () {
      expect(provider.status, NotificationsStatusState.ready);

      final request = _userRows.requests.first;
      expect(request['isActive'], isTrue);
      expect(request['sortBy'], NotificationsProvider.sortBy);

      // A closed account cannot be written to, so it is not offered.
      expect(provider.allRecipients.map((user) => user.id), [4, 2, 3]);
      expect(provider.totalCount, 3);
    });

    test('resolves each recipient role for the list', () {
      expect(provider.roleOf(provider.allRecipients.first), 'Production worker');
      expect(
          provider.roleOf(
              provider.allRecipients.firstWhere((user) => user.id == 2)),
          'Project manager');
    });

    test('starts addressed to everyone', () {
      expect(provider.toEveryone, isTrue);
      expect(provider.selectedCount, 3);
      expect(provider.allRecipients.every((user) => provider.isSelected(user.id)),
          isTrue);
      expect(provider.canSend, isTrue);
    });

    test('narrows the list by name, e-mail or role', () {
      provider.setSearch('kovacevic');
      expect(provider.recipients.map((user) => user.id), [3]);

      provider.setSearch('selma@');
      expect(provider.recipients.map((user) => user.id), [2]);

      provider.setSearch('worker');
      expect(provider.recipients.map((user) => user.id), [4, 3]);

      // The search only narrows what is shown, never who is addressed.
      expect(provider.selectedCount, 3);
    });

    test('unticking somebody while addressed to all switches to picking by hand',
        () {
      provider.toggle(2);

      expect(provider.toEveryone, isFalse);
      expect(provider.selectedIds, {4, 3});
      expect(provider.isSelected(2), isFalse);
      expect(provider.selectedCount, 2);
    });

    test('refuses to send with nobody picked', () {
      provider.setToEveryone(false);

      expect(provider.selectedCount, 0);
      expect(provider.canSend, isFalse);
    });

    test('leaves the ids off when the message goes to everyone', () async {
      final sent = await provider.send(title: 'Shutdown', message: 'No work Friday.');

      // The API resolves the list, so it cannot go stale between load and send.
      expect(_notifications.sent.single, {
        'title': 'Shutdown',
        'message': 'No work Friday.',
        'userIds': null,
      });
      expect(sent, 3);
    });

    test('sends only the ticked ids when they were picked by hand', () async {
      provider.toggle(2);
      provider.toggle(4);

      final sent = await provider.send(title: 'Overtime', message: 'Saturday shift.');

      expect(_notifications.sent.single['userIds'], [3]);
      expect(sent, 1);
    });

    test('goes back to everyone when the selection is cleared', () {
      provider.toggle(2);
      provider.setSearch('emir');

      provider.clearSelection();

      expect(provider.toEveryone, isTrue);
      expect(provider.selectedIds, isEmpty);
      expect(provider.search, isEmpty);
      expect(provider.selectedCount, 3);
    });
  });

  testWidgets('notifications screen renders the form and the recipients',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationsScreen(providerFactory: _fakeNotifications)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Send Notification'), findsWidgets);
    expect(find.text('Create and send a notification to your workers'),
        findsOneWidget);
    expect(find.text('Message details'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    expect(find.text('Recipients'), findsOneWidget);
    expect(find.text('All workers'), findsOneWidget);
    expect(find.text('Selected workers'), findsOneWidget);
    expect(find.text('Vedran Alagic'), findsOneWidget);
    expect(find.text('3 of 3 selected'), findsOneWidget);
  });

  testWidgets('an empty form refuses to send', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationsScreen(providerFactory: _fakeNotifications)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.pumpAndSettle();

    expect(find.text('A notification needs a title.'), findsOneWidget);
    expect(find.text('A notification needs a message.'), findsOneWidget);
    expect(_notifications.sent, isEmpty);
  });

  testWidgets('a filled form sends and says how many it reached', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationsScreen(providerFactory: _fakeNotifications)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate((widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title'),
      'Shutdown Friday',
    );
    await tester.enterText(
      find.byWidgetPredicate((widget) =>
          widget is TextField && widget.decoration?.labelText == 'Message'),
      'No production on 12 September.',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.pumpAndSettle();

    expect(_notifications.sent.single['title'], 'Shutdown Friday');
    expect(find.text('Notification sent to 3 people'), findsOneWidget);
  });

  testWidgets('the API message is what the form shows when a send fails',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: NotificationsScreen(providerFactory: _fakeNotifications)),
    ));
    await tester.pumpAndSettle();

    _notifications.failure = ApiClientException('There is nobody to send this to.');

    await tester.enterText(
      find.byWidgetPredicate((widget) =>
          widget is TextField && widget.decoration?.labelText == 'Title'),
      'Shutdown',
    );
    await tester.enterText(
      find.byWidgetPredicate((widget) =>
          widget is TextField && widget.decoration?.labelText == 'Message'),
      'No production.',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.pumpAndSettle();

    expect(find.text('There is nobody to send this to.'), findsOneWidget);
  });
}
