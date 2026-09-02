import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/generated_report.dart';
import 'base_provider.dart';

/// The three `/Report` endpoints. It rides on [BaseProvider] for the auth
/// header, the one-shot refresh after a 401 and the API's own error messages —
/// but these endpoints answer `application/pdf`, never JSON, so the type
/// parameter is only there to satisfy the base class and [fromJson] is unused.
class ReportProvider extends BaseProvider<GeneratedReport> {
  ReportProvider() : super('Report');

  /// Hours per worker for one month, split into regular and overtime.
  Future<Uint8List> monthlyWorkHours({
    required int year,
    required int month,
    int? userId,
    int? projectId,
  }) =>
      _post('MonthlyWorkHours', {
        'year': year,
        'month': month,
        'userId': userId,
        'projectId': projectId,
      });

  /// Every load with its carrier, driver, vehicle, weight and status.
  Future<Uint8List> transportLoads({
    int? projectId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) =>
      _post('TransportLoads', {
        'projectId': projectId,
        'dateFrom': dateFrom?.toIso8601String(),
        'dateTo': dateTo?.toIso8601String(),
      });

  /// Rebuilds a past report from the parameters it was first run with. Nothing
  /// stores the PDF, so this re-runs it against today's data.
  Future<Uint8List> download(int generatedReportId) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}$endpoint/$generatedReportId/Download');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return response.bodyBytes;
  }

  Future<Uint8List> _post(String action, Map<String, dynamic> body) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$action');

    final response = await send(
      (headers) => http.post(uri, headers: headers, body: jsonEncode(body)),
    );

    validateResponse(response);
    return response.bodyBytes;
  }
}
