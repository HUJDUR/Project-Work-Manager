import '../models/generated_report.dart';
import '../models/report_queue_state.dart';
import '../utils/api_client_exception.dart';
import '../utils/sarajevo_time.dart';
import 'base_provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;



/// The `/Report` endpoints. Generating one no longer answers the PDF directly -
/// `pwm.Worker` is a separate process, off RabbitMQ, that renders it - so a
/// request here only ever queues the row and hands back its id; poll [status]
/// until it says "Completed", then [download]. It rides on [BaseProvider] for
/// the auth header, the one-shot refresh after a 401 and the API's own error
/// messages.
class ReportProvider extends BaseProvider<GeneratedReport> {
  ReportProvider() : super('Report');

  @override
  GeneratedReport fromJson(dynamic data) =>
      GeneratedReport.fromJson(data as Map<String, dynamic>);

  /// Hours per worker for one month, split into regular and overtime.
  Future<ReportQueueState> monthlyWorkHours({
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
  Future<ReportQueueState> transportLoads({
    int? projectId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) =>
      _post('TransportLoads', {
        'projectId': projectId,
        'dateFrom': dateFrom == null ? null : SarajevoTime.toApi(dateFrom),
        'dateTo': dateTo == null ? null : SarajevoTime.toApi(dateTo),
      });

  /// What [monthlyWorkHours]/[transportLoads] is up to right now.
  Future<ReportQueueState> status(int generatedReportId) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}$endpoint/$generatedReportId/Status');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return ReportQueueState.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// The PDF `pwm.Worker` rendered. Throws the API's own message if the report
  /// is not "Completed" yet - callers are expected to have polled [status] first.
  Future<Uint8List> download(int generatedReportId) async {
    final uri =
        Uri.parse('${BaseProvider.baseUrl}$endpoint/$generatedReportId/Download');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return response.bodyBytes;
  }

  Future<ReportQueueState> _post(String action, Map<String, dynamic> body) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$action');

    final response = await send(
      (headers) => http.post(uri, headers: headers, body: jsonEncode(body)),
    );

    validateResponse(response);
    return ReportQueueState.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

/// Polls [ReportProvider.status] until the report is done, on the interval and
/// timeout every caller of it agrees on - see `ReportsProvider.generate` and
/// `.openRecent`, the only two places a report is ever waited on.
extension ReportPolling on ReportProvider {
  static const _pollInterval = Duration(milliseconds: 800);
  static const _timeout = Duration(seconds: 30);

  Future<void> awaitCompletion(int generatedReportId) async {
    final deadline = DateTime.now().add(_timeout);

    while (true) {
      final state = await status(generatedReportId);

      switch (state.runStatus) {
        case ReportRunStatus.completed:
          return;
        case ReportRunStatus.failed:
          throw ApiClientException(
            state.errorMessage ?? 'The report could not be generated.',
          );
        case ReportRunStatus.pending:
        case ReportRunStatus.processing:
          if (DateTime.now().isAfter(deadline)) {
            throw ApiClientException(
              'This is taking longer than expected. Check Recent Reports shortly.',
            );
          }
          await Future.delayed(_pollInterval);
      }
    }
  }
}
