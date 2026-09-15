import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recommendation_result.dart';
import 'base_provider.dart';

/// The `/Recommendation` endpoint. Rides on [BaseProvider] purely for the auth
/// header, the one-shot refresh after a 401 and the API's own error messages -
/// the same bargain [ReportProvider] makes, and for the same reason: the one
/// action here does not fit `get`/`insert`/`update`/`remove`.
class RecommendationApiProvider extends BaseProvider<RecommendationResult> {
  RecommendationApiProvider() : super('Recommendation');

  Future<RecommendationResult> estimate({
    required int projectCategoryId,
    required double tonnes,
    required int workingDays,
  }) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/Estimate');

    final response = await send((headers) => http.post(
          uri,
          headers: headers,
          body: jsonEncode({
            'projectCategoryId': projectCategoryId,
            'tonnes': tonnes,
            'workingDays': workingDays,
          }),
        ));

    validateResponse(response);

    return RecommendationResult.fromJson(jsonDecode(response.body));
  }
}
