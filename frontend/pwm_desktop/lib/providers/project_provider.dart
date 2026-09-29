import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/project.dart';
import '../models/project_overview.dart';
import 'base_provider.dart';

class ProjectProvider extends BaseProvider<Project> {
  ProjectProvider() : super('Project');

  @override
  Project fromJson(data) => Project.fromJson(data);

  /// `PATCH /Project/{id}/Status` - the only way `projectStatusId` ever
  /// changes. See `ProjectStatusRules` on the API for the legal jumps; a
  /// jump it refuses comes back as an [ApiClientException] via
  /// [validateResponse].
  Future<Project> changeStatus(int id, int newStatusId) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/Status');
    final body = jsonEncode({'projectStatusId': newStatusId});

    final response =
        await send((headers) => http.patch(uri, headers: headers, body: body));

    validateResponse(response);
    return fromJson(jsonDecode(response.body));
  }

  /// `GET /Project/{id}/StatusHistory` - newest first.
  Future<List<ProjectStatusChangeEntry>> statusHistory(int id) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/StatusHistory');

    final response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => ProjectStatusChangeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
