// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResult _$LoginResultFromJson(Map<String, dynamic> json) => LoginResult(
  accesstoken: json['accesstoken'] as String,
  refreshtoken: json['refreshtoken'] as String,
  expiresAt: const ApiDateTimeConverter().fromJson(json['expiresAt'] as String),
  role: json['role'] as String,
  user: User.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LoginResultToJson(LoginResult instance) =>
    <String, dynamic>{
      'accesstoken': instance.accesstoken,
      'refreshtoken': instance.refreshtoken,
      'expiresAt': const ApiDateTimeConverter().toJson(instance.expiresAt),
      'role': instance.role,
      'user': instance.user.toJson(),
    };
