import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.userTypeId,
    required this.isActive,
    this.phoneNumber,
    this.jobTitle,
  });

  final int id;
  final String name;
  final String surname;
  final String email;
  final int userTypeId;
  final bool isActive;
  final String? phoneNumber;
  final String? jobTitle;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get fullName => '$name $surname'.trim();

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get initials {
    final first = name.isEmpty ? '' : name[0];
    final last = surname.isEmpty ? '' : surname[0];
    final combined = '$first$last'.toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
