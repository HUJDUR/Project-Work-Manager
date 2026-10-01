import '../utils/sarajevo_time.dart';

/// One block of work booked against a project, resolved to the worker and
/// operation names `ProjectOverviewProvider` joins in - what the read-only
/// Project Details page's "Work on Project" table shows.
class ProjectWorkEntry {
  const ProjectWorkEntry({
    required this.id,
    required this.workerName,
    required this.operationName,
    required this.date,
    required this.hours,
  });

  final int id;
  final String workerName;
  final String operationName;
  final DateTime date;
  final double hours;
}

/// Every hour booked under one operation, added up across [ProjectWorkEntry]
/// - the "Operations Summary" table.
class ProjectOperationSummary {
  const ProjectOperationSummary({required this.operationName, required this.totalHours});

  final String operationName;
  final double totalHours;
}

/// One truck load carrying this project, resolved to the carrier and status
/// names - the "Transport / Loads" table. The weight is this project's own
/// share of the load, not the whole truck's.
class ProjectTransportEntry {
  const ProjectTransportEntry({
    required this.id,
    required this.truckLoadId,
    required this.loadDate,
    required this.carrierName,
    required this.weight,
    required this.statusName,
  });

  final int id;
  final int truckLoadId;
  final DateTime loadDate;
  final String carrierName;
  final double weight;
  final String statusName;

  /// The mockup's Load No. There is no such column - a load is identified by
  /// its id, in the same shape `TransportRow.transportNo` already writes it.
  String get loadNo => 'TR-${truckLoadId.toString().padLeft(4, '0')}';
}

/// One row of a project's status history, exactly as `GET
/// /Project/{id}/StatusHistory` hands it back - names already resolved
/// server-side, so there is nothing here to join. Newest first.
class ProjectStatusChangeEntry {
  const ProjectStatusChangeEntry({
    required this.id,
    required this.toStatusName,
    required this.changedByName,
    required this.changedAt,
    this.fromStatusName,
    this.reason,
  });

  final int id;

  /// Null for the row a project's own creation writes.
  final String? fromStatusName;

  final String toStatusName;
  final String changedByName;
  final DateTime changedAt;

  /// Why - set only on a rejection.
  final String? reason;

  factory ProjectStatusChangeEntry.fromJson(Map<String, dynamic> json) =>
      ProjectStatusChangeEntry(
        id: json['id'] as int,
        fromStatusName: json['fromStatusName'] as String?,
        toStatusName: json['toStatusName'] as String,
        changedByName: json['changedByName'] as String,
        changedAt: SarajevoTime.fromApi(json['changedAt'] as String),
        reason: json['reason'] as String?,
      );
}
