import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dashboard_data.dart';
import 'base_provider.dart';

/// `GET /Dashboard` - every number, chart and list on the Dashboard in one
/// request, aggregated by the API.
class DashboardApiProvider extends BaseProvider<DashboardData> {
  DashboardApiProvider() : super('Dashboard');

  @override
  DashboardData fromJson(dynamic data) =>
      DashboardData.fromJson(data as Map<String, dynamic>);

  Future<DashboardData> fetch() async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    return fromJson(jsonDecode(response.body));
  }
}
