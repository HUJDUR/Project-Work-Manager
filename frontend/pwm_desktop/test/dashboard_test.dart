import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwm_desktop/models/models.dart';
import 'package:pwm_desktop/providers/dashboard_api_provider.dart';
import 'package:pwm_desktop/providers/dashboard_provider.dart';
import 'package:pwm_desktop/screens/dashboard_screen.dart';
import 'package:pwm_desktop/utils/api_client_exception.dart';

class _FakeApi extends DashboardApiProvider {
  _FakeApi(this.json);

  final Map<String, dynamic> json;

  @override
  Future<DashboardData> fetch() async => fromJson(json);
}

class _FailingApi extends DashboardApiProvider {
  @override
  Future<DashboardData> fetch() async => throw ApiClientException('The API is unreachable.');
}

final _yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));

/// The shape `GET /Dashboard` answers with.
Map<String, dynamic> _response() => {
      'windowDays': 30,
      'hoursLogged': 10,
      'activeProjects': 2,
      'inProduction': 2,
      'activeWorkers': 2,
      'workersWithBookings': 2,
      'transports': 1,
      'shippedWeight': 12000,
      'hoursByProject': [
        {'label': 'Hall roof MU-1', 'shortLabel': 'P-1', 'value': 7},
        {'label': 'Railing MU-2', 'shortLabel': 'P-2', 'value': 3},
      ],
      'hoursByOperation': [
        {'label': 'Welding', 'shortLabel': null, 'value': 7},
        {'label': 'Cutting', 'shortLabel': null, 'value': 3},
      ],
      'recentWork': [
        {
          'workerName': 'Emir Kovacevic',
          'workerInitials': 'EK',
          'projectName': 'Hall roof MU-1',
          'operationName': 'Welding',
          'hours': 5,
          'startedAt': _yesterday.toIso8601String(),
        },
      ],
      'recentTransports': [
        {
          'driverName': 'Ivan Maric',
          'vehicleRegistration': 'A12-B-345',
          'carrierName': 'TransBalkan Logistika',
          'loadDate': _yesterday.toIso8601String(),
          'netWeight': 12000,
        },
      ],
      'recentActivity': [
        {'title': 'Project created', 'actorName': 'Selma Delic', 'date': _yesterday.toIso8601String()},
      ],
    };

DashboardProvider _fakeDashboard() => DashboardProvider(api: _FakeApi(_response()));

void main() {
  group('DashboardProvider', () {
    late DashboardProvider controller;

    setUp(() {
      controller = _fakeDashboard();
    });

    test('reports ready once the dashboard has loaded', () async {
      await controller.load();

      expect(controller.status, DashboardStatus.ready);
      expect(controller.data, isNotNull);
    });

    test('words the summary cards from the API counts', () async {
      await controller.load();

      SummaryMetric metric(String label) =>
          controller.data!.metrics.firstWhere((metric) => metric.label == label);

      expect(metric('Hours logged').value, '10 h');
      expect(metric('Active projects').value, '2');
      expect(metric('Active projects').caption, '2 in production');
      expect(metric('Workers').caption, '2 booked hours');
      expect(metric('Transports').value, '1');
      expect(metric('Shipped weight').value, '12.0 t');
    });

    test('puts the project code on the axis and the full name in the tooltip', () async {
      await controller.load();

      final slice = controller.data!.hoursByProject.first;

      expect(slice.label, 'Hall roof MU-1');
      expect(slice.shortLabel, 'P-1');
      expect(slice.axisLabel, 'P-1');
      expect(slice.value, 7);
    });

    test('an operation has no code, so its axis label is its name', () async {
      await controller.load();

      final slice = controller.data!.hoursByOperation.first;

      expect(slice.shortLabel, isNull);
      expect(slice.axisLabel, 'Welding');
    });

    test('reads the list panels as the API names them', () async {
      await controller.load();

      final work = controller.data!.recentWork.single;
      expect(work.workerName, 'Emir Kovacevic');
      expect(work.workerInitials, 'EK');

      final transport = controller.data!.recentTransports.single;
      expect(transport.driverName, 'Ivan Maric');
      expect(transport.carrierName, 'TransBalkan Logistika');

      final activity = controller.data!.recentActivity.single;
      expect(activity.title, 'Project created');
      expect(activity.actorName, 'Selma Delic');
    });

    test('surfaces an error state when the dashboard cannot be loaded', () async {
      final failing = DashboardProvider(api: _FailingApi());

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
