import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_mobile/models/models.dart';
import 'package:pwm_mobile/providers/clock_in_api_provider.dart';
import 'package:pwm_mobile/providers/clock_in_provider.dart';
import 'package:pwm_mobile/screens/clock_in_screen.dart';
import 'package:pwm_mobile/utils/api_client_exception.dart';
import 'package:pwm_mobile/utils/sarajevo_time.dart';

/// Stands in for the API: answers the options it was given and records what
/// the screen asked for. The rules themselves - who, when, overlaps - are the
/// server's, so all the phone is tested for here is what it sends and shows.
class _FakeApi extends ClockInApiProvider {
  _FakeApi({
    this.session,
    this.projects = const [ClockInOption(id: 1, name: '26-015 - Staircase module')],
    this.operations = const [ClockInOption(id: 4, name: 'Welding')],
    this.refuseWith,
  });

  ActiveSession? session;
  final List<ClockInOption> projects;
  final List<ClockInOption> operations;

  /// A message the API refuses clocking in with, as its `ClientException` would.
  final String? refuseWith;

  final List<(int projectId, int operationTypeId)> clockIns = [];
  final List<String?> notes = [];
  int clockOuts = 0;

  @override
  Future<ClockInOptions> options() async =>
      (session: session, projects: projects, operations: operations);

  @override
  Future<ActiveSession> clockIn({
    required int projectId,
    required int operationTypeId,
    String? note,
  }) async {
    final refusal = refuseWith;
    if (refusal != null) throw ApiClientException(refusal);

    clockIns.add((projectId, operationTypeId));
    notes.add(note);
    return session = ActiveSession(
      id: 900,
      workLogId: 500,
      projectLabel: projects.firstWhere((p) => p.id == projectId).name,
      operationName: operations.firstWhere((o) => o.id == operationTypeId).name,
      startedAt: SarajevoTime.now(),
      note: note,
    );
  }

  @override
  Future<void> clockOut() async {
    clockOuts++;
    session = null;
  }
}

class _FailingApi extends ClockInApiProvider {
  @override
  Future<ClockInOptions> options() async => throw ApiClientException('The API is unreachable.');
}

ActiveSession _running({Duration ago = const Duration(hours: 1, minutes: 30)}) => ActiveSession(
      id: 900,
      workLogId: 500,
      projectLabel: '26-015 - Staircase module',
      operationName: 'Welding',
      startedAt: SarajevoTime.now().subtract(ago),
    );

void main() {
  group('what can be picked', () {
    test('only what the API offers: projects in production, qualified operations', () async {
      final provider = ClockInProvider(api: _FakeApi());
      await provider.load();

      expect(provider.status, ClockInStatus.ready);
      expect(provider.projectOptions.map((p) => p.name), ['26-015 - Staircase module']);
      expect(provider.operationOptions.map((o) => o.name), ['Welding']);
    });

    test('a pick that is no longer offered does not survive a reload', () async {
      final api = _FakeApi();
      final provider = ClockInProvider(api: api);
      await provider.load();
      provider.selectProject(1);
      provider.selectOperation(4);

      final narrower = ClockInProvider(api: _FakeApi(projects: const []));
      await narrower.load();
      narrower.selectProject(1);
      await narrower.load();

      expect(narrower.selectedProjectId, isNull);
      expect(provider.selectedProjectId, 1);
    });

    test('says what is missing before anything is picked', () async {
      final provider = ClockInProvider(api: _FakeApi());
      await provider.load();
      expect(provider.clockInBlockedReason, 'Pick a project and an operation.');

      final unqualified = ClockInProvider(api: _FakeApi(operations: const []));
      await unqualified.load();
      expect(unqualified.clockInBlockedReason, contains('not qualified'));
    });
  });

  group('clocking in', () {
    test('sends only the project and the operation - never who or when', () async {
      final api = _FakeApi();
      final provider = ClockInProvider(api: api);
      await provider.load();
      provider
        ..selectProject(1)
        ..selectOperation(4);

      await provider.clockIn();

      expect(api.clockIns, [(1, 4)]);
      expect(api.notes, [null]);
      expect(provider.active?.projectLabel, '26-015 - Staircase module');
      expect(provider.selectedProjectId, isNull);
    });

    test('sends the optional note trimmed, and clears it for the next session', () async {
      final api = _FakeApi();
      final provider = ClockInProvider(api: api);
      await provider.load();
      provider
        ..selectProject(1)
        ..selectOperation(4)
        ..setNote('  Waiting for material  ');

      await provider.clockIn();

      expect(api.notes, ['Waiting for material']);
      expect(provider.active?.note, 'Waiting for material');
      expect(provider.note, isEmpty);
    });

    test('a running session blocks another', () async {
      final provider = ClockInProvider(api: _FakeApi(session: _running()));
      await provider.load();

      expect(provider.hasActiveSession, isTrue);
      expect(provider.clockInBlockedReason, 'Clock out of your current session first.');
      expect(provider.canClockIn, isFalse);
    });

    test("the API's refusal comes through in its own words", () async {
      final provider = ClockInProvider(
          api: _FakeApi(refuseWith: 'Already clocked in since 30.09.2026 07:00 - that session has to be closed first.'));
      await provider.load();
      provider
        ..selectProject(1)
        ..selectOperation(4);

      await expectLater(
        provider.clockIn(),
        throwsA(isA<ApiClientException>().having((e) => e.message, 'message', contains('Already clocked in'))),
      );
      expect(provider.isSubmitting, isFalse);
      expect(provider.hasActiveSession, isFalse);
    });
  });

  group('clocking out', () {
    test('asks the API to close the session, and clears it', () async {
      final api = _FakeApi(session: _running());
      final provider = ClockInProvider(api: api);
      await provider.load();

      await provider.clockOut();

      expect(api.clockOuts, 1);
      expect(provider.hasActiveSession, isFalse);
    });

    test('does nothing when nothing is running', () async {
      final api = _FakeApi();
      final provider = ClockInProvider(api: api);
      await provider.load();

      await provider.clockOut();

      expect(api.clockOuts, 0);
    });

    test('elapsed time never runs backwards on a phone whose clock is behind', () {
      final session = _running(ago: const Duration(minutes: -5));

      expect(session.elapsedAt(SarajevoTime.now()), Duration.zero);
    });
  });

  group('the screen', () {
    Future<void> pump(WidgetTester tester, ClockInProvider provider) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClockInScreen(providerFactory: () => provider)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lays out both halves of the mockup', (tester) async {
      await pump(tester, ClockInProvider(api: _FakeApi()));

      expect(find.text('Active Session'), findsOneWidget);
      expect(find.text('Start New Session'), findsOneWidget);
      expect(find.text('Project'), findsOneWidget);
      expect(find.text('Operation'), findsOneWidget);
      expect(find.text('Clock In'), findsOneWidget);
      // Nothing is running, so there is nothing to clock out of.
      expect(find.text('Nothing running'), findsOneWidget);
      expect(find.text('Clock Out'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a running session shows its rows and the way out', (tester) async {
      await pump(tester, ClockInProvider(api: _FakeApi(session: _running())));

      // Twice, as the mockup draws it: the card's title line and the Project row.
      expect(find.text('26-015 - Staircase module'), findsNWidgets(2));
      expect(find.text('Welding'), findsOneWidget);
      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('Elapsed Time'), findsOneWidget);
      expect(find.text('Clock Out'), findsOneWidget);
      expect(find.text('Nothing running'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the note can be typed before clocking in and shows on the session',
        (tester) async {
      final api = _FakeApi();
      final provider = ClockInProvider(api: api);
      await pump(tester, provider);
      provider
        ..selectProject(1)
        ..selectOperation(4);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('clock-in-note')), 'Crane was busy');
      await tester.tap(find.text('Clock In'));
      await tester.pumpAndSettle();

      expect(api.notes, ['Crane was busy']);
      expect(find.text('Note'), findsNWidgets(2));
      expect(find.text('Crane was busy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      await pump(tester, ClockInProvider(api: _FailingApi()));

      expect(find.text('The API is unreachable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
