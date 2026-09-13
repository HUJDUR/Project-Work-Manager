import 'package:json_annotation/json_annotation.dart';

part 'user_operation.g.dart';

@JsonSerializable()
class UserOperation {
  const UserOperation({
    required this.id,
    required this.userId,
    required this.operationTypeId,
  });

  final int id;
  final int userId;
  final int operationTypeId;

  factory UserOperation.fromJson(Map<String, dynamic> json) =>
      _$UserOperationFromJson(json);

  Map<String, dynamic> toJson() => _$UserOperationToJson(this);
}
