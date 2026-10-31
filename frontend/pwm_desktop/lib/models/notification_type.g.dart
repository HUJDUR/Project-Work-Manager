// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationType _$NotificationTypeFromJson(Map<String, dynamic> json) =>
    NotificationType(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      isSystem: json['isSystem'] as bool? ?? false,
    );

Map<String, dynamic> _$NotificationTypeToJson(NotificationType instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'isSystem': instance.isSystem,
    };
