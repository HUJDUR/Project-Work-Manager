import 'package:json_annotation/json_annotation.dart';
import '../utils/sarajevo_time.dart';

part 'notification.g.dart';

/// One message the office sent to one person — the table has no notion of a
/// message sent to many, so a broadcast is a row per recipient.
///
/// Collides with Flutter's own `Notification`; a file needing both imports
/// `package:flutter/material.dart` with a `hide Notification` clause. This is
/// the desktop's model verbatim, the same bargain the `User`/`WorkLog` models
/// strike — one fix, both apps.
@JsonSerializable(converters: [ApiDateTimeConverter()])
class Notification {
  const Notification({
    required this.id,
    required this.userId,
    this.notificationTypeId = 0,
    this.notificationTypeName = '',
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int userId;

  @JsonKey(defaultValue: 0)
  final int notificationTypeId;

  @JsonKey(defaultValue: '')
  final String notificationTypeName;

  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  /// The same row with [isRead] flipped, so the list can show a notification as
  /// read the moment the API accepts it rather than refetching the page.
  @JsonKey(includeFromJson: false, includeToJson: false)
  Notification get read => Notification(
        id: id,
        userId: userId,
        notificationTypeId: notificationTypeId,
        notificationTypeName: notificationTypeName,
        title: title,
        message: message,
        isRead: true,
        createdAt: createdAt,
      );

  factory Notification.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationToJson(this);
}
