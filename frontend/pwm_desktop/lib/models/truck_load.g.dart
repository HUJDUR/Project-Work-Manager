// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'truck_load.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TruckLoad _$TruckLoadFromJson(Map<String, dynamic> json) => TruckLoad(
  id: (json['id'] as num).toInt(),
  transportCompanyId: (json['transportCompanyId'] as num).toInt(),
  truckLoadStatusId: (json['truckLoadStatusId'] as num).toInt(),
  loadDate: const ApiDateTimeConverter().fromJson(json['loadDate'] as String),
  driverName: json['driverName'] as String,
  driverSurname: json['driverSurname'] as String,
  vehicleRegistration: json['vehicleRegistration'] as String,
  emptyWeight: (json['emptyWeight'] as num).toDouble(),
  fullWeight: (json['fullWeight'] as num).toDouble(),
  note: json['note'] as String?,
  price: (json['price'] as num?)?.toDouble(),
);

Map<String, dynamic> _$TruckLoadToJson(TruckLoad instance) => <String, dynamic>{
  'id': instance.id,
  'transportCompanyId': instance.transportCompanyId,
  'truckLoadStatusId': instance.truckLoadStatusId,
  'loadDate': const ApiDateTimeConverter().toJson(instance.loadDate),
  'driverName': instance.driverName,
  'driverSurname': instance.driverSurname,
  'vehicleRegistration': instance.vehicleRegistration,
  'emptyWeight': instance.emptyWeight,
  'fullWeight': instance.fullWeight,
  'note': instance.note,
  'price': instance.price,
};
