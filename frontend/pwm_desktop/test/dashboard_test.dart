import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/base_provider.dart';
import 'package:pwm_desktop/providers/dashboard_provider.dart';
import 'package:pwm_desktop/screens/dashboard_screen.dart';
import 'package:pwm_desktop/utils/api_client_exception.dart';

class _FakeProvider<T> extends BaseProvider<T> {
  _FakeProvider(this.rows) : super('Fake');

  final List<T> rows;

  @override
  Future<PageResult<T>> get({dynamic filter}) async => PageResult<T>()..items = rows;
}

class _FailingProvider<T> extends BaseProvider<T> {
  _FailingProvider() : super('Fake');

  @override
  Future<PageResult<T>> get({dynamic filter}) async =>
      throw ApiClientException('The API is unreachable.');
}

/// Dates are relative to `now`, keeping every row inside the 30-day window.
final _now = DateTime.now();
final _yesterday = _now.subtract(const Duration(days: 1));
final _twoDaysAgo = _now.subtract(const Duration(days: 2));

Project _project({required int id, required String name, required int statusId}) =>
    Project(
      id: id,
      customerId: 1,
      name: name,
      code: 'P-$id',
      weight: 1000,
      projectCategoryId: 1,
      creationDate: _now,
      projectStatusId: statusId,
      createdByUserId: 1,
    );

DashboardProvider _fakeDashboard() => DashboardProvider(
      projects: _FakeProvider([
        _project(id: 1, name: 'Hall roof MU-1', statusId: 3),
        _project(id: 2, name: 'Railing MU-2', statusId: 3),
        _project(id: 3, name: 'Trial WM-9', statusId: 6),
        _project(id: 4, name: 'Frame NM-3', statusId: 5),
      ]),
      users: _FakeProvider(const [
        User(
            id: 1,
            name: 'Emir',
            surname: 'Kovacevic',
            email: 'e@pwm.ba',
            userTypeId: 3,
            isActive: true),
        User(
            id: 2,
            name: 'Damir',
            surname: 'Softic',
            email: 'd@pwm.ba',
            userTypeId: 3,
            isActive: true),
        User(
            id: 3,
            name: 'Mirza',
            surname: 'Tufekcic',
            email: 'm@pwm.ba',
            userTypeId: 3,
            isActive: false),
        User(
            id: 4,
            name: 'Selma',
            surname: 'Delic',
            email: 's@pwm.ba',
            userTypeId: 2,
            isActive: true),
      ]),
      companies: _FakeProvider(const [
        Company(
            id: 7,
            name: 'TransBalkan Logistika',
            cityId: 1,
            address: 'Put 1',
            companyTypeId: 2),
      ]),
      workLogs: _FakeProvider([
        WorkLog(id: 10, userId: 1, clockedIn: _yesterday, hours: 8),
        WorkLog(id: 11, userId: 2, clockedIn: _twoDaysAgo, hours: 8),
      ]),
      workLogDetails: _FakeProvider([
        WorkLogDetail(
            id: 100,
            workLogId: 10,
            operationTypeId: 4,
            projectId: 1,
            startedAt: _yesterday,
            hours: 5),
        WorkLogDetail(
            id: 101,
            workLogId: 10,
            operationTypeId: 1,
            projectId: 2,
            startedAt: _yesterday,
            hours: 3),
        WorkLogDetail(
            id: 102,
            workLogId: 11,
            operationTypeId: 4,
            projectId: 1,
            startedAt: _twoDaysAgo,
            hours: 2),
        // Older than the 30-day window, so it must not reach the charts.
        WorkLogDetail(
            id: 103,
            workLogId: 11,
            operationTypeId: 1,
            projectId: 1,
            startedAt: _now.subtract(const Duration(days: 90)),
            hours: 99),
      ]),
      truckLoads: _FakeProvider([
        TruckLoad(
          id: 50,
          transportCompanyId: 7,
          truckLoadStatusId: 1,
          loadDate: _yesterday,
          driverName: 'Ivan',
          driverSurname: 'Maric',
          vehicleRegistration: 'A12-B-345',
          emptyWeight: 8000,
          fullWeight: 20000,
        ),
      ]),
      activityLogs: _FakeProvider([
        ActivityLog(id: 1, userId: 1, activityLogTypeId: 3, date: _twoDaysAgo),
        ActivityLog(id: 2, userId: 4, activityLogTypeId: 5, date: _yesterday),
      ]),
      projectStatusTypes: _FakeProvider(const [
        ProjectStatusType(id: 3, name: 'In production'),
        ProjectStatusType(id: 5, name: 'Delivered'),
        ProjectStatusType(id: 6, name: 'Cancelled'),
      ]),
      operationTypes: _FakeProvider(const [
        OperationType(id: 1, name: 'Cutting'),
        OperationType(id: 4, name: 'Welding'),
      ]),
      activityLogTypes: _FakeProvider(const [
        ActivityLogType(id: 3, name: 'Clock in'),
        ActivityLogType(id: 5, name: 'Project created'),
      ]),
      userTypes: _FakeProvider(const [
        UserType(id: 2, type: 'Manager'),
        UserType(id: 3, type: 'Worker'),
      ]),
    );

void main() {
  group('DashboardProvider', () {
    late DashboardProvider controller;

    setUp(() {
      controller = _fakeDashboard();
    });

    test('reports ready once every table has loaded', () async {
      await controller.load();

      expect(controller.status, DashboardStatus.ready);
      expect(controller.data, isNotNull);
    });

    test('counts only projects that are neither delivered nor cancelled', () async {
      await controller.load();

      final activeProjects = controller.data!.metrics
          .firstWhere((metric) => metric.label == 'Active projects');

      expect(activeProjects.value, '2');
      expect(activeProjects.caption, '2 in production');
    });

    test('sums hours inside the window only and labels them by project', () async {
      await controller.load();

      final hours =
          controller.data!.metrics.firstWhere((metric) => metric.label == 'Hours logged');
      expect(hours.value, '10 h');

      final byProject = controller.data!.hoursByProject;
      expect(byProject.map((slice) => slice.label), ['Hall roof MU-1', 'Railing MU-2']);
      expect(byProject.first.value, 7);
    });

    test('groups hours by operation type, largest share first', () async {
      await controller.load();

      final byOperation = controller.data!.hoursByOperation;
      expect(byOperation.map((slice) => slice.label), ['Welding', 'Cutting']);
      expect(byOperation.first.value, 7);
    });

    test('counts active workers and excludes managers', () async {
      await controller.load();

      final workers =
          controller.data!.metrics.firstWhere((metric) => metric.label == 'Workers');

      expect(workers.value, '2');
      expect(workers.caption, '2 booked hours');
    });

    test('reports transport count and shipped cargo weight in tonnes', () async {
      await controller.load();

      final metrics = controller.data!.metrics;
      expect(metrics.firstWhere((metric) => metric.label == 'Transports').value, '1');
      expect(
          metrics.firstWhere((metric) => metric.label == 'Shipped weight').value, '12.0 t');
    });

    test('resolves foreign keys into names for the list panels', () async {
      await controller.load();

      final work = controller.data!.recentWork.first;
      expect(work.workerName, 'Emir Kovacevic');
      expect(work.workerInitials, 'EK');
      expect(work.projectName, isNotEmpty);

      final transport = controller.data!.recentTransports.single;
      expect(transport.driverName, 'Ivan Maric');
      expect(transport.carrierName, 'TransBalkan Logistika');

      final activity = controller.data!.recentActivity.first;
      expect(activity.title, 'Project created');
      expect(activity.actorName, 'Selma Delic');
    });

    test('surfaces an error state when a table cannot be loaded', () async {
      final failing = DashboardProvider(projects: _FailingProvider<Project>());

      await failing.load();

      expect(failing.status, DashboardStatus.failed);
      expect(failing.errorMessage, 'The API is unreachable.');
    });
  });

  testWidgets('dashboard renders the summary, charts and lists', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DashboardScreen(providerFactory: _fakeDashboard),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Hours by project'), findsOneWidget);
    expect(find.text('Hours by operation'), findsOneWidget);
    expect(find.text('Latest work'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Emir Kovacevic'), findsWidgets);
  });
}
