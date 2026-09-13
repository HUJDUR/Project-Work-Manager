import 'work_log_detail.dart';

/// The block of work the signed-in worker is on right now, with the names its
/// ids stand for already resolved.
///
/// A session is one `WorkLogDetail` — project plus operation, started and not
/// yet finished — hanging off the `WorkLog` that is the shift it belongs to.
/// It is "running" precisely because `FinishedAt` is still null, which is what
/// the nullable column on both tables exists for.
class ActiveSession {
  const ActiveSession({
    required this.block,
    required this.projectLabel,
    required this.operationName,
  });

  final WorkLogDetail block;

  /// "26-015 - Staircase module".
  final String projectLabel;

  final String operationName;

  DateTime get startedAt => block.startedAt;

  int get id => block.id;

  int get workLogId => block.workLogId;

  /// How long it has been running as of [now]. Never negative — a phone whose
  /// clock is behind the server's would otherwise count backwards.
  Duration elapsedAt(DateTime now) {
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }
}
