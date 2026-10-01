import '../utils/sarajevo_time.dart';

/// One row of a transport's status history, exactly as `GET
/// /TruckLoad/{id}/StatusHistory` hands it back - names already resolved
/// server-side, so there is nothing here to join. Newest first.
class TruckLoadStatusChangeEntry {
  const TruckLoadStatusChangeEntry({
    required this.id,
    required this.toStatusName,
    required this.changedByName,
    required this.changedAt,
    this.fromStatusName,
    this.reason,
  });

  final int id;

  /// Null for the row a load's own creation writes.
  final String? fromStatusName;

  final String toStatusName;
  final String changedByName;
  final DateTime changedAt;

  /// Why - set only on a rejection.
  final String? reason;

  factory TruckLoadStatusChangeEntry.fromJson(Map<String, dynamic> json) =>
      TruckLoadStatusChangeEntry(
        id: json['id'] as int,
        fromStatusName: json['fromStatusName'] as String?,
        toStatusName: json['toStatusName'] as String,
        changedByName: json['changedByName'] as String,
        changedAt: SarajevoTime.fromApi(json['changedAt'] as String),
        reason: json['reason'] as String?,
      );
}
