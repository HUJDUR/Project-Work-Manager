// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Project _$ProjectFromJson(Map<String, dynamic> json) => Project(
  id: (json['id'] as num).toInt(),
  customerId: (json['customerId'] as num).toInt(),
  name: json['name'] as String,
  weight: (json['weight'] as num).toDouble(),
  createdByUserId: (json['createdByUserId'] as num).toInt(),
  code: json['code'] as String,
  description: json['description'] as String?,
  notes: json['notes'] as String?,
  priority: (json['priority'] as num?)?.toInt() ?? 2,
  projectCategoryId: (json['projectCategoryId'] as num).toInt(),
  creationDate: const ApiDateTimeConverter().fromJson(
    json['creationDate'] as String,
  ),
  projectStatusId: (json['projectStatusId'] as num).toInt(),
  deliveryDate: _$JsonConverterFromJson<String, DateTime>(
    json['deliveryDate'],
    const ApiDateTimeConverter().fromJson,
  ),
  deliveryCompanyId: (json['deliveryCompanyId'] as num?)?.toInt(),
  productionStartDate: _$JsonConverterFromJson<String, DateTime>(
    json['productionStartDate'],
    const ApiDateTimeConverter().fromJson,
  ),
);

Map<String, dynamic> _$ProjectToJson(Project instance) => <String, dynamic>{
  'id': instance.id,
  'customerId': instance.customerId,
  'name': instance.name,
  'weight': instance.weight,
  'createdByUserId': instance.createdByUserId,
  'code': instance.code,
  'description': instance.description,
  'notes': instance.notes,
  'priority': instance.priority,
  'projectCategoryId': instance.projectCategoryId,
  'creationDate': const ApiDateTimeConverter().toJson(instance.creationDate),
  'projectStatusId': instance.projectStatusId,
  'deliveryDate': _$JsonConverterToJson<String, DateTime>(
    instance.deliveryDate,
    const ApiDateTimeConverter().toJson,
  ),
  'deliveryCompanyId': instance.deliveryCompanyId,
  'productionStartDate': _$JsonConverterToJson<String, DateTime>(
    instance.productionStartDate,
    const ApiDateTimeConverter().toJson,
  ),
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
