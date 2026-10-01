import '../models/monthly_hour_report.dart';
import '../models/monthly_hour_report_overview.dart';
import 'base_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MonthlyHourReportProvider extends BaseProvider<MonthlyHourReport> {
  MonthlyHourReportProvider() : super('MonthlyHourReport');

  @override
  MonthlyHourReport fromJson(data) => MonthlyHourReport.fromJson(data);

  Future<MonthlyHourReportOverview> overview(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/Overview');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return MonthlyHourReportOverview.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
