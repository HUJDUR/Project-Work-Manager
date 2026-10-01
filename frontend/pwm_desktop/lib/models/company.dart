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
    this.isActive = true,
  });

  final int id;
  final String name;
  final int countryId;
  final int cityId;
  final String address;
  final int companyTypeId;
  final String? vat;
  final String? eori;

  /// A deactivated company keeps its projects and transports but is not
  /// offered for new ones.
  @JsonKey(defaultValue: true)
  final bool isActive;

  /// Whether a picker offers it: active ones, plus the one a record already
  /// points at, so editing that record does not lose its company.
  bool isSelectableFor(int? currentId) => isActive || id == currentId;

  factory Company.fromJson(Map<String, dynamic> json) => _$CompanyFromJson(json);

  Map<String, dynamic> toJson() => _$CompanyToJson(this);
}
