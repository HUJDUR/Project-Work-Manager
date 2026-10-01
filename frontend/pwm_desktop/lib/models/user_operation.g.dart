// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_operation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserOperation _$UserOperationFromJson(Map<String, dynamic> json) =>
    UserOperation(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      operationTypeId: (json['operationTypeId'] as num).toInt(),
    );

Map<String, dynamic> _$UserOperationToJson(UserOperation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'operationTypeId': instance.operationTypeId,
    };
