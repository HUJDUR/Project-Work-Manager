import '../models/monthly_hour_report.dart';
import '../utils/api_client_exception.dart';
import '../utils/sarajevo_time.dart';
import 'monthly_hour_report_provider.dart';
import 'package:flutter/foundation.dart';

enum MonthlyReportsStatus { idle, loading, ready, failed }

/// The Monthly Reports list: newest month first, a year at a time or all of them.
class MonthlyReportsProvider with ChangeNotifier {
  MonthlyReportsProvider({MonthlyHourReportProvider? api})
      : _api = api ?? MonthlyHourReportProvider();

  final MonthlyHourReportProvider _api;

  static const int pageSize = 12;

  MonthlyReportsStatus status = MonthlyReportsStatus.idle;
  String? errorMessage;

  List<MonthlyHourReport> months = [];
  int page = 1;
  int pageCount = 1;

  /// Null shows every year.
  int? year;

  MonthlyHourReportProvider get api => _api;

  /// The years the filter offers: this one and the four before it.
  List<int> get years {
    final now = SarajevoTime.now().year;
    return [for (var y = now; y > now - 5; y--) y];
  }

  /// The month still being booked - its figures are not final yet.
  static bool isInProgress(MonthlyHourReport report) {
    final now = SarajevoTime.now();
    return report.year == now.year && report.month == now.month;
  }

  Future<void> load() async {
    status = MonthlyReportsStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.get(filter: {
        'year': year,
        'page': page,
        'pageSize': pageSize,
        'includeTotalCount': true,
        'sortBy': 'Year desc, Month desc',
      });

      months = result.items;
      final total = result.totalCount ?? months.length;
      pageCount = total == 0 ? 1 : (total / pageSize).ceil();
      status = MonthlyReportsStatus.ready;
    } on ApiClientException catch (error) {
      errorMessage = error.message;
      status = MonthlyReportsStatus.failed;
    } catch (error) {
      errorMessage = 'Monthly reports could not be loaded: $error';
      status = MonthlyReportsStatus.failed;
    }

    notifyListeners();
  }

  Future<void> setYear(int? value) {
    year = value;
    page = 1;
    return load();
  }

  Future<void> setPage(int value) {
    page = value;
    return load();
  }
}
