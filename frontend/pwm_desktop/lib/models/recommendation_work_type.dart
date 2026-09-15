import 'package:json_annotation/json_annotation.dart';

part 'recommendation_work_type.g.dart';

/// Mirrors `pwm.Model.Responses.RecommendationWorkTypeResponse` - one row of the
/// estimate's work-type breakdown.
@JsonSerializable()
class RecommendationWorkType {
  const RecommendationWorkType({
    required this.operationTypeId,
    required this.operationTypeName,
    required this.estimatedHours,
    required this.sharePercent,
  });

  final int operationTypeId;
  final String operationTypeName;
  final double estimatedHours;
  final double sharePercent;

  factory RecommendationWorkType.fromJson(Map<String, dynamic> json) =>
      _$RecommendationWorkTypeFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationWorkTypeToJson(this);
}
