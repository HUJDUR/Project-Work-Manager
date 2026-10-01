import 'monthly_hour_report.dart';

/// `GET /MonthlyHourReport/{id}/Overview`: one month opened.
class MonthlyHourReportOverview {
  const MonthlyHourReportOverview({
    required this.month,
    required this.workers,
    required this.operations,
  });

  final MonthlyHourReport month;
  final List<MonthlyHourReportWorker> workers;

  /// Busiest first.
  final List<MonthlyHourReportOperation> operations;

  factory MonthlyHourReportOverview.fromJson(Map<String, dynamic> json) =>
      MonthlyHourReportOverview(
        month: MonthlyHourReport.fromJson(json['month'] as Map<String, dynamic>),
        workers: [
          for (final row in json['workers'] as List)
            MonthlyHourReportWorker.fromJson(row as Map<String, dynamic>),
        ],
        operations: [
          for (final row in json['operations'] as List)
            MonthlyHourReportOperation.fromJson(row as Map<String, dynamic>),
        ],
      );
}

class MonthlyHourReportWorker {
  const MonthlyHourReportWorker({
    required this.userId,
    required this.workerName,
    required this.daysWorked,
    required this.regularHours,
    required this.overtimeHours,
    required this.totalHours,
  });

  final int userId;
  final String workerName;
  final int daysWorked;
  final double regularHours;
  final double overtimeHours;
  final double totalHours;

  factory MonthlyHourReportWorker.fromJson(Map<String, dynamic> json) =>
      MonthlyHourReportWorker(
        userId: json['userId'] as int,
        workerName: json['workerName'] as String,
        daysWorked: json['daysWorked'] as int,
        regularHours: (json['regularHours'] as num).toDouble(),
        overtimeHours: (json['overtimeHours'] as num).toDouble(),
        totalHours: (json['totalHours'] as num).toDouble(),
      );
}

class MonthlyHourReportOperation {
  const MonthlyHourReportOperation({required this.operationName, required this.hours});

  final String operationName;
  final double hours;

  factory MonthlyHourReportOperation.fromJson(Map<String, dynamic> json) =>
      MonthlyHourReportOperation(
        operationName: json['operationName'] as String,
        hours: (json['hours'] as num).toDouble(),
      );
}
