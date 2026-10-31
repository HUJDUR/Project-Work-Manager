import 'package:json_annotation/json_annotation.dart';

part 'notification_type.g.dart';

@JsonSerializable()
class NotificationType {
  const NotificationType({required this.id, required this.name, this.isSystem = false});

  final int id;
  final String name;

  /// Raised only by the API and the worker - never offered on the send form.
  @JsonKey(defaultValue: false)
  final bool isSystem;

  factory NotificationType.fromJson(Map<String, dynamic> json) =>
      _$NotificationTypeFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationTypeToJson(this);
}
