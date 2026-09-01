import 'package:json_annotation/json_annotation.dart';

part 'truck_load_status_type.g.dart';

@JsonSerializable()
class TruckLoadStatusType {
  const TruckLoadStatusType({required this.id, required this.name});

  final int id;
  final String name;

  factory TruckLoadStatusType.fromJson(Map<String, dynamic> json) =>
      _$TruckLoadStatusTypeFromJson(json);

  Map<String, dynamic> toJson() => _$TruckLoadStatusTypeToJson(this);
}
