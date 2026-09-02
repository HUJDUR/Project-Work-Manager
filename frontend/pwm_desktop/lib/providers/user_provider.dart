import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'base_provider.dart';

class UserProvider extends BaseProvider<User> {
  UserProvider() : super('User');

  @override
  User fromJson(data) => User.fromJson(data);

  /// `PUT /User/Me` — the signed-in user editing their own account. It is not
  /// [update]: that one is administrator-only and carries a role and an active
  /// flag, neither of which anyone may set on themselves. Which account it
  /// applies to is the token's business, so no id is sent.
  Future<User> updateProfile({
    required String name,
    required String surname,
    required String email,
    String? phoneNumber,
    String? jobTitle,
    String? currentPassword,
    String? newPassword,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/Me');
    final body = jsonEncode({
      'name': name,
      'surname': surname,
      'email': email,
      'phoneNumber': phoneNumber,
      'jobTitle': jobTitle,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });

    final response =
        await send((headers) => http.put(uri, headers: headers, body: body));

    validateResponse(response);
    return fromJson(jsonDecode(response.body));
  }
}
