import 'package:json_annotation/json_annotation.dart';

part 'truck_load_detail.g.dart';

@JsonSerializable()
class TruckLoadDetail {
  const TruckLoadDetail({
    required this.id,
    required this.truckLoadId,
    required this.projectId,
    required this.brutoWeight,
    required this.netoWeight,
    required this.unloadPriority,
    required this.unloadColor,
  });

  final int id;
  final int truckLoadId;
  final int projectId;
  final double brutoWeight;
  final double netoWeight;
  final int unloadPriority;
  final String unloadColor;

  factory TruckLoadDetail.fromJson(Map<String, dynamic> json) =>
      _$TruckLoadDetailFromJson(json);

  Map<String, dynamic> toJson() => _$TruckLoadDetailToJson(this);
}
