import 'generated_report.dart';

/// Mirrors both `ReportQueuedResponse` (from the enqueue POST) and
/// `ReportStatusResponse` (from polling `GET Report/{id}/Status`) - the two
/// ever answer the same shape, just under a different id key.
class ReportQueueState {
  const ReportQueueState({
    required this.id,
    required this.status,
    this.errorMessage,
  });

  final int id;
  final String status;

  /// Set only when [status] is "Failed".
  final String? errorMessage;

  ReportRunStatus get runStatus => ReportRunStatus.fromName(status);

  factory ReportQueueState.fromJson(Map<String, dynamic> json) => ReportQueueState(
        id: (json['generatedReportId'] ?? json['id']) as int,
        status: json['status'] as String,
        errorMessage: json['errorMessage'] as String?,
      );
}
