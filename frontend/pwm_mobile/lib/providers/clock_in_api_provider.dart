import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/active_session.dart';
import '../models/clock_in_option.dart';
import 'base_provider.dart';

/// What the Clock In screen can offer, as `GET /WorkLog/ClockIn` answers it.
typedef ClockInOptions = ({
  ActiveSession? session,
  List<ClockInOption> projects,
  List<ClockInOption> operations,
});

/// Clocking in and out, which the API does in one step each: it takes who from
/// the token and when from its own clock, checks the booking, and writes the
/// shift and the session together. The phone only says what - project and
/// operation - so it can neither pick the time nor book for somebody else.
class ClockInApiProvider extends BaseProvider<ActiveSession> {
  ClockInApiProvider() : super('WorkLog');

  @override
  ActiveSession fromJson(dynamic data) => ActiveSession.fromJson(data as Map<String, dynamic>);

  Future<ClockInOptions> options() async {
    final json = await _send('GET', 'ClockIn') as Map<String, dynamic>;
    final session = json['session'];

    return (
      session: session == null ? null : fromJson(session),
      projects: _options(json['projects']),
      operations: _options(json['operations']),
    );
  }

  Future<ActiveSession> clockIn({
    required int projectId,
    required int operationTypeId,
    String? note,
  }) async =>
      fromJson(await _send('POST', 'ClockIn', {
        'projectId': projectId,
        'operationTypeId': operationTypeId,
        'note': note,
      }));

  Future<void> clockOut() => _send('POST', 'ClockOut');

  static List<ClockInOption> _options(dynamic rows) => [
        for (final row in rows as List) ClockInOption.fromJson(row as Map<String, dynamic>),
      ];

  Future<dynamic> _send(String method, String action, [Object? body]) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$action');

    final response = await send((headers) => method == 'GET'
        ? http.get(uri, headers: headers)
        : http.post(uri, headers: headers, body: jsonEncode(body ?? const {})));

    validateResponse(response);
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }
}
