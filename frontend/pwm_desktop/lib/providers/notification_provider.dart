import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/notification.dart';
import 'base_provider.dart';

class NotificationProvider extends BaseProvider<Notification> {
  NotificationProvider() : super('Notification');

  @override
  Notification fromJson(data) => Notification.fromJson(data);

  /// Posts one message to `POST /Notification/Send`, which fans it out into one
  /// row per recipient and answers how many that was. Reading the table is the
  /// generic list; this is the only way into it. Null [userIds] means everyone
  /// whose account still works.
  Future<int> sendNotification({
    required String title,
    required String message,
    List<int>? userIds,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/Send');
    final body = jsonEncode({
      'title': title,
      'message': message,
      'userIds': userIds,
    });

    final response =
        await send((headers) => http.post(uri, headers: headers, body: body));

    validateResponse(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return data['sentCount'] as int? ?? 0;
  }
}
