import 'package:json_annotation/json_annotation.dart';

part 'operation_type.g.dart';

@JsonSerializable()
class OperationType {
  const OperationType({required this.id, required this.name});

  final int id;
  final String name;

  factory OperationType.fromJson(Map<String, dynamic> json) =>
      _$OperationTypeFromJson(json);

  Map<String, dynamic> toJson() => _$OperationTypeToJson(this);
}
