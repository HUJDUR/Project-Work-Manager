import '../models/work_day.dart';
import '../models/work_log_detail.dart';
import 'base_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WorkLogDetailProvider extends BaseProvider<WorkLogDetail> {
  WorkLogDetailProvider() : super('WorkLogDetail');

  @override
  WorkLogDetail fromJson(data) => WorkLogDetail.fromJson(data);

  /// `GET /WorkLogDetail/MyDays` - one page of the signed-in worker's days in
  /// a period; whose comes from the token.
  Future<WorkDaysPage> myDays({
    required DateTime from,
    required DateTime to,
    required int page,
    required int pageSize,
  }) async {
    final query = getQueryString({
      'dateFrom': from,
      'dateTo': to,
      'page': page,
      'pageSize': pageSize,
    });
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/MyDays?$query');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return WorkDaysPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
