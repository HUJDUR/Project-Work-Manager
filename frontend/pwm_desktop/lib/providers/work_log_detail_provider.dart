import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/work_hours_change.dart';
import '../models/work_log_detail.dart';
import 'base_provider.dart';

class WorkLogDetailProvider extends BaseProvider<WorkLogDetail> {
  WorkLogDetailProvider() : super('WorkLogDetail');

  @override
  WorkLogDetail fromJson(data) => WorkLogDetail.fromJson(data);

  /// `GET /WorkLogDetail/{id}/History` - who corrected this block, when, and
  /// from what to what. Newest first.
  Future<List<WorkHoursChange>> history(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/History');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return [
      for (final row in jsonDecode(response.body) as List)
        WorkHoursChange.fromJson(row as Map<String, dynamic>),
    ];
  }
}
