import '../utils/sarajevo_time.dart';

/// The block of work the signed-in worker is on right now, as the API describes
/// it - project and operation already named, start time the server's own.
///
/// A session is one `WorkLogDetail` hanging off the `WorkLog` that is the shift
/// it belongs to; it is running because its finish is still empty.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.workLogId,
    required this.projectLabel,
    required this.operationName,
    required this.startedAt,
    this.note,
  });

  final int id;

  final int workLogId;

  /// "26-015 - Staircase module".
  final String projectLabel;

  final String operationName;

  final DateTime startedAt;

  /// What the worker added when clocking in, if anything.
  final String? note;

  /// One `ClockSessionResponse` from the API.
  factory ActiveSession.fromJson(Map<String, dynamic> json) => ActiveSession(
        id: json['workLogDetailId'] as int,
        workLogId: json['workLogId'] as int,
        projectLabel: json['projectLabel'] as String,
        operationName: json['operationName'] as String,
        startedAt: SarajevoTime.fromApi(json['startedAt'] as String),
        note: json['note'] as String?,
      );

  /// How long it has been running as of [now]. Never negative — a phone whose
  /// clock is behind the server's would otherwise count backwards.
  Duration elapsedAt(DateTime now) {
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }
}
