import 'package:json_annotation/json_annotation.dart';

import 'user.dart';
import '../utils/sarajevo_time.dart';

part 'login_result.g.dart';

/// Mirrors `pwm.Model.Access.UserLoginResponse`: the tokens plus the account
/// they were issued for, so the app knows who is signed in without decoding the JWT.
@JsonSerializable(explicitToJson: true, converters: [ApiDateTimeConverter()])
class LoginResult {
  const LoginResult({
    required this.accesstoken,
    required this.refreshtoken,
    required this.expiresAt,
    required this.role,
    required this.user,
  });

  final String accesstoken;
  final String refreshtoken;
  final DateTime expiresAt;

  /// Administrator, Manager or Worker.
  final String role;

  final User user;

  factory LoginResult.fromJson(Map<String, dynamic> json) => _$LoginResultFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResultToJson(this);
}
