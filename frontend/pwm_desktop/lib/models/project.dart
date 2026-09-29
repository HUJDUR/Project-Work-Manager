import 'package:json_annotation/json_annotation.dart';

import 'project_priority.dart';
import '../utils/sarajevo_time.dart';

part 'project.g.dart';

@JsonSerializable(converters: [ApiDateTimeConverter()])
class Project {
  const Project({
    required this.id,
    required this.customerId,
    required this.name,
    required this.weight,
    required this.createdByUserId,
    required this.code,
    this.description,
    this.notes,
    this.priority = 2,
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

  /// Who raised the project.
  final int createdByUserId;

  /// The shop's own reference for the job, e.g. MU-2201.
  final String code;

  final String? description;
  final String? notes;

  /// The stored int; read it through [priorityLevel].
  final int priority;
  final int projectCategoryId;
  final DateTime creationDate;
  final int projectStatusId;
  final DateTime? deliveryDate;
  final int? deliveryCompanyId;
  final DateTime? productionStartDate;

  @JsonKey(includeFromJson: false, includeToJson: false)
  ProjectPriority get priorityLevel => ProjectPriority.fromValue(priority);

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectToJson(this);
}
