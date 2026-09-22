import 'package:json_annotation/json_annotation.dart';

part 'company.g.dart';

@JsonSerializable()
class Company {
  const Company({
    required this.id,
    required this.name,
    required this.countryId,
    required this.cityId,
    required this.address,
    required this.companyTypeId,
    this.vat,
    this.eori,
  });

  final int id;
  final String name;
  final int countryId;
  final int cityId;
  final String address;
  final int companyTypeId;
  final String? vat;
  final String? eori;

  factory Company.fromJson(Map<String, dynamic> json) => _$CompanyFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyToJson(this);
}
