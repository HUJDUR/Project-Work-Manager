import '../utils/sarajevo_time.dart';

/// One correction the office made to a block of work, as
/// `GET /WorkLogDetail/{id}/History` hands it back - newest first.
class WorkHoursChange {
  const WorkHoursChange({
    required this.action,
    required this.changedByName,
    required this.changedAt,
    this.before,
    this.after,
  });

  /// "Added", "Changed" or "Deleted".
  final String action;
  final String changedByName;
  final DateTime changedAt;

  /// The block in words as it was - null for an addition.
  final String? before;

  /// The same, after the change - null for a deletion.
  final String? after;

  factory WorkHoursChange.fromJson(Map<String, dynamic> json) => WorkHoursChange(
        action: json['action'] as String,
        changedByName: json['changedByName'] as String,
        changedAt: SarajevoTime.fromApi(json['changedAt'] as String),
        before: json['before'] as String?,
        after: json['after'] as String?,
      );
}
