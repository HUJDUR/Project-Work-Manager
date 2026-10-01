// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Company _$CompanyFromJson(Map<String, dynamic> json) => Company(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  countryId: (json['countryId'] as num).toInt(),
  cityId: (json['cityId'] as num).toInt(),
  address: json['address'] as String,
  companyTypeId: (json['companyTypeId'] as num).toInt(),
  vat: json['vat'] as String?,
  eori: json['eori'] as String?,
);

Map<String, dynamic> _$CompanyToJson(Company instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'countryId': instance.countryId,
  'cityId': instance.cityId,
  'address': instance.address,
  'companyTypeId': instance.companyTypeId,
  'vat': instance.vat,
  'eori': instance.eori,
};
