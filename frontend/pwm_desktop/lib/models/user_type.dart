import 'package:json_annotation/json_annotation.dart';

part 'user_type.g.dart';

@JsonSerializable()
class UserType {
  const UserType({required this.id, required this.type});

  final int id;
  final String type;

  factory UserType.fromJson(Map<String, dynamic> json) => _$UserTypeFromJson(json);

  Map<String, dynamic> toJson() => _$UserTypeToJson(this);
}
