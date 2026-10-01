import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../utils/api_client_exception.dart';
import 'dashboard_api_provider.dart';

enum DashboardStatus { idle, loading, ready, failed }

/// The Dashboard's state. Every count, sum and grouping is the API's -
/// `GET /Dashboard` - so this only tracks loading and failure.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({DashboardApiProvider? api}) : _api = api ?? DashboardApiProvider();

  final DashboardApiProvider _api;

  DashboardStatus _status = DashboardStatus.idle;
  DashboardData? _data;
  String? _errorMessage;

  DashboardStatus get status => _status;
  DashboardData? get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DashboardStatus.loading;

  Future<void> load() async {
    _status = DashboardStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _api.fetch();
      _status = DashboardStatus.ready;
    } on ApiClientException catch (error) {
      _errorMessage = error.message;
      _status = DashboardStatus.failed;
    } catch (error) {
      _errorMessage = 'Something went wrong while loading the dashboard: $error';
      _status = DashboardStatus.failed;
    }

    notifyListeners();
  }
}
