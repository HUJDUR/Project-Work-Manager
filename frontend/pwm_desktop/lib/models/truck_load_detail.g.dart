// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'truck_load_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TruckLoadDetail _$TruckLoadDetailFromJson(Map<String, dynamic> json) =>
    TruckLoadDetail(
      id: (json['id'] as num).toInt(),
      truckLoadId: (json['truckLoadId'] as num).toInt(),
      projectId: (json['projectId'] as num).toInt(),
      brutoWeight: (json['brutoWeight'] as num).toDouble(),
      netoWeight: (json['netoWeight'] as num).toDouble(),
      unloadPriority: (json['unloadPriority'] as num).toInt(),
      unloadColor: json['unloadColor'] as String,
    );

Map<String, dynamic> _$TruckLoadDetailToJson(TruckLoadDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'truckLoadId': instance.truckLoadId,
      'projectId': instance.projectId,
      'brutoWeight': instance.brutoWeight,
      'netoWeight': instance.netoWeight,
      'unloadPriority': instance.unloadPriority,
      'unloadColor': instance.unloadColor,
    };
