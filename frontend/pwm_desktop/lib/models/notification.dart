import 'package:json_annotation/json_annotation.dart';

part 'notification.g.dart';

/// Collides with Flutter's own `Notification`; import that one with a `hide`.
@JsonSerializable()
class Notification {
  const Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  factory Notification.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationToJson(this);
}
