import 'package:json_annotation/json_annotation.dart';
import '../utils/sarajevo_time.dart';

part 'notification.g.dart';

/// Collides with Flutter's own `Notification`; import that one with a `hide`.
@JsonSerializable(converters: [ApiDateTimeConverter()])
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

  /// The same row with [isRead] flipped, so the bell's popup can show a
  /// notification as read the moment the API accepts it rather than
  /// refetching the page.
  @JsonKey(includeFromJson: false, includeToJson: false)
  Notification get read => Notification(
        id: id,
        userId: userId,
        title: title,
        message: message,
        isRead: true,
        createdAt: createdAt,
      );

  factory Notification.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationToJson(this);
}
