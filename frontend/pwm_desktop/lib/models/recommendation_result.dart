import 'package:json_annotation/json_annotation.dart';

import 'recommendation_work_type.dart';

part 'recommendation_result.g.dart';

/// Mirrors `pwm.Model.Responses.RecommendationResponse` - the answer from
/// `POST /Recommendation/Estimate`.
@JsonSerializable()
class RecommendationResult {
  const RecommendationResult({
    required this.hasEstimate,
    this.message,
    this.explanation,
    required this.sampleSize,
    this.accuracyPercent,
    required this.totalHours,
    required this.estimatedWorkers,
    required this.estimatedDurationDays,
    required this.workTypes,
  });

  /// False when the category has too little delivered history - see [message]
  /// for why. No other field is meaningful when this is false.
  final bool hasEstimate;

  final String? message;

  /// Set only when [hasEstimate] is true: plain-language account of what the
  /// estimate is based on, so it is never shown as a bare number.
  final String? explanation;

  final int sampleSize;
  /// Null when the past projects' hours do not vary, so there is nothing to
  /// measure the fit against.
  final double? accuracyPercent;
  final double totalHours;
  final int estimatedWorkers;
  final int estimatedDurationDays;
  final List<RecommendationWorkType> workTypes;

  factory RecommendationResult.fromJson(Map<String, dynamic> json) =>
      _$RecommendationResultFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationResultToJson(this);
}
