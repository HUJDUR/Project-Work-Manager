// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Notification _$NotificationFromJson(Map<String, dynamic> json) => Notification(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  notificationTypeId: (json['notificationTypeId'] as num?)?.toInt() ?? 0,
  notificationTypeName: json['notificationTypeName'] as String? ?? '',
  title: json['title'] as String,
  message: json['message'] as String,
  isRead: json['isRead'] as bool,
  createdAt: const ApiDateTimeConverter().fromJson(json['createdAt'] as String),
);

Map<String, dynamic> _$NotificationToJson(Notification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'notificationTypeId': instance.notificationTypeId,
      'notificationTypeName': instance.notificationTypeName,
      'title': instance.title,
      'message': instance.message,
      'isRead': instance.isRead,
      'createdAt': const ApiDateTimeConverter().toJson(instance.createdAt),
    };
