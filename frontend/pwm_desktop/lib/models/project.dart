import 'package:json_annotation/json_annotation.dart';

part 'project.g.dart';

@JsonSerializable()
class Project {
  const Project({
    required this.id,
    required this.customerId,
    required this.name,
    required this.weight,
    required this.projectCategoryId,
    required this.creationDate,
    required this.projectStatusId,
    this.deliveryDate,
    this.deliveryCompanyId,
    this.productionStartDate,
  });

  final int id;
  final int customerId;
  final String name;
  final double weight;
  final int projectCategoryId;
  final DateTime creationDate;
  final int projectStatusId;
  final DateTime? deliveryDate;
  final int? deliveryCompanyId;
  final DateTime? productionStartDate;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectToJson(this);
}
