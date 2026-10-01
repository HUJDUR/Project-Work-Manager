// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OperationType _$OperationTypeFromJson(Map<String, dynamic> json) =>
    OperationType(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$OperationTypeToJson(OperationType instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};
