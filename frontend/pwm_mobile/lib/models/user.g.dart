// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  surname: json['surname'] as String,
  email: json['email'] as String,
  userTypeId: (json['userTypeId'] as num).toInt(),
  isActive: json['isActive'] as bool,
  phoneNumber: json['phoneNumber'] as String?,
  picture: json['picture'] as String?,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'surname': instance.surname,
  'email': instance.email,
  'userTypeId': instance.userTypeId,
  'isActive': instance.isActive,
  'phoneNumber': instance.phoneNumber,
  'picture': instance.picture,
};
