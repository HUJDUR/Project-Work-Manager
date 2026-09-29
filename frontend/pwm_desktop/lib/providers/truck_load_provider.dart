import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/transport_overview.dart';
import '../models/truck_load.dart';
import 'base_provider.dart';

class TruckLoadProvider extends BaseProvider<TruckLoad> {
  TruckLoadProvider() : super('TruckLoad');

  @override
  TruckLoad fromJson(data) => TruckLoad.fromJson(data);

  /// `PATCH /TruckLoad/{id}/Status` - the only way `truckLoadStatusId` ever
  /// changes. [price] is the invoice amount in EUR, required only when
  /// [newStatusId] is "Finished" - see `TruckLoadStatusRules` on the API for
  /// the legal jumps; a jump it refuses comes back as an [ApiClientException]
  /// via [validateResponse].
  Future<TruckLoad> changeStatus(int id, int newStatusId, {double? price}) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/Status');
    final body = jsonEncode({'truckLoadStatusId': newStatusId, 'price': price});

    final response =
        await send((headers) => http.patch(uri, headers: headers, body: body));

    validateResponse(response);
    return fromJson(jsonDecode(response.body));
  }

  /// `GET /TruckLoad/{id}/StatusHistory` - newest first.
  Future<List<TruckLoadStatusChangeEntry>> statusHistory(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/StatusHistory');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => TruckLoadStatusChangeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
