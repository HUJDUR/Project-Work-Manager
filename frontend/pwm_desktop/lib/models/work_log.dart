import 'package:json_annotation/json_annotation.dart';
import '../utils/sarajevo_time.dart';

part 'work_log.g.dart';

@JsonSerializable(converters: [ApiDateTimeConverter()])
class WorkLog {
  const WorkLog({
    required this.id,
    required this.userId,
    required this.clockedIn,
    required this.hours,
    this.clockedOut,
  });

  final int id;
  final int userId;
  final DateTime clockedIn;
  final double hours;
  final DateTime? clockedOut;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isOpen => clockedOut == null;

  factory WorkLog.fromJson(Map<String, dynamic> json) => _$WorkLogFromJson(json);

  Map<String, dynamic> toJson() => _$WorkLogToJson(this);
}
