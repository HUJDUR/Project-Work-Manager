import 'package:json_annotation/json_annotation.dart';

part 'city.g.dart';

@JsonSerializable()
class City {
  const City({
    required this.id,
    required this.name,
    required this.postalCode,
    required this.countryId,
  });

  final int id;
  final String name;
  final String postalCode;
  final int countryId;

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  Map<String, dynamic> toJson() => _$CityToJson(this);
}
