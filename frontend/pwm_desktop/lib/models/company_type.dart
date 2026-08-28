import 'package:json_annotation/json_annotation.dart';

part 'company_type.g.dart';

@JsonSerializable()
class CompanyType {
  const CompanyType({required this.id, required this.name});

  final int id;
  final String name;

  factory CompanyType.fromJson(Map<String, dynamic> json) => _$CompanyTypeFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyTypeToJson(this);
}
