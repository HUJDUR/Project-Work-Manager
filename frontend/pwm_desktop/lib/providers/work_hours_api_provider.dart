import '../models/work_hours_entry.dart';
import 'base_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// `GET /WorkLogDetail/Hours` - the Work Hours screen's rows, joined, split into
/// regular and overtime, filtered, sorted and paged by the API. Read-only:
/// writes go through `WorkLogDetail`.
class WorkHoursApiProvider extends BaseProvider<WorkHoursEntry> {
  WorkHoursApiProvider() : super('WorkLogDetail/Hours');

  @override
  WorkHoursEntry fromJson(dynamic data) =>
      WorkHoursEntry.fromJson(data as Map<String, dynamic>);

  /// One page, with the totals of the whole filtered set.
  Future<WorkHoursPage> page(Map<String, dynamic> filter) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint?${getQueryString(filter)}');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return WorkHoursPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
