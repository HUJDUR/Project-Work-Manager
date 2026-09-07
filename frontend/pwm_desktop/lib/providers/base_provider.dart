import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import '../models/page_result.dart';
import '../utils/api_client_exception.dart';
import 'auth_provider.dart';

abstract class BaseProvider<T> with ChangeNotifier {
  /// Must end in a slash: routes are built as `{baseUrl}{endpoint}`.
  static const String baseUrl = String.fromEnvironment(
    "baseUrl",
    defaultValue: "http://localhost:7094/",
  );

  /// The largest page the API will serve: `BaseSearchObject.MaxPageSize` clamps
  /// anything bigger, so asking for a whole table in one request does not work.
  static const int maxPageSize = 100;

  /// Stops [getAll] running away if the API ever keeps answering with full pages.
  static const int _maxPages = 200;

  /// API resource segment, e.g. `Project` -> `{baseUrl}Project`.
  final String endpoint;

  BaseProvider(this.endpoint);

  /// Every row of a lookup table, walked one capped page at a time. Use it for the
  /// small reference tables; a table that can grow belongs behind a real filter.
  Future<List<T>> getAll({Map<String, dynamic>? filter}) async {
    final rows = <T>[];

    for (var page = 1; page <= _maxPages; page++) {
      final result = await get(filter: {
        ...?filter,
        'page': page,
        'pageSize': maxPageSize,
        'includeTotalCount': false,
      });

      rows.addAll(result.items);

      if (result.items.length < maxPageSize) break;
    }

    return rows;
  }

  Future<PageResult<T>> get({dynamic filter}) async {
    var url = "$baseUrl$endpoint";
    if (filter != null) {
      var queryString = getQueryString(filter);
      url = "$url?$queryString";
    }

    var uri = Uri.parse(url);

    var response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    var data = jsonDecode(response.body);

    var result = PageResult<T>();

    result.totalCount = data['totalCount'];
    result.items = List<T>.from(data["items"].map((e) => fromJson(e)));

    return result;
  }

  Future<T> getById(int id) async {
    var url = "$baseUrl$endpoint/$id";
    var uri = Uri.parse(url);

    var response = await send((headers) => http.get(uri, headers: headers));

    validateResponse(response);
    var data = jsonDecode(response.body);

    return fromJson(data);
  }

  Future<T> insert(dynamic request) async {
    var url = "$baseUrl$endpoint";
    var uri = Uri.parse(url);
    var jsonRequest = jsonEncode(request);

    var response =
        await send((headers) => http.post(uri, headers: headers, body: jsonRequest));

    validateResponse(response);
    var data = jsonDecode(response.body);

    return fromJson(data);
  }

  Future<T> update(int id, [dynamic request]) async {
    var url = "$baseUrl$endpoint/$id";
    var uri = Uri.parse(url);
    var jsonRequest = jsonEncode(request);

    var response =
        await send((headers) => http.put(uri, headers: headers, body: jsonRequest));

    validateResponse(response);
    var data = jsonDecode(response.body);

    return fromJson(data);
  }

  Future remove(int id) async {
    var url = "$baseUrl$endpoint/$id";
    var uri = Uri.parse(url);

    var response = await send((headers) => http.delete(uri, headers: headers));

    validateResponse(response);
  }

  /// Sends the request, and once the access token has expired, retries it with a
  /// fresh one rather than making the user sign in again mid-session.
  @protected
  Future<Response> send(Future<Response> Function(Map<String, String> headers) request) async {
    var response = await request(createHeaders());

    if (response.statusCode == 401 && await AuthProvider.tryRefresh()) {
      response = await request(createHeaders());
    }

    return response;
  }

  T fromJson(dynamic data) {
    throw Exception("Method not implemented");
  }

  /// Throws [ApiClientException] with a message from the API when status is not successful.
  void validateResponse(Response response) {
    if (response.statusCode < 299) {
      return;
    }
    if (response.statusCode == 401) {
      throw ApiClientException(
        'Your session has expired. Please sign in again.',
      );
    }

    final parsed = ApiErrorParser.messageFromBody(response.body);
    if (response.statusCode >= 500) {
      throw ApiClientException(
        parsed ?? 'Server error. Please try again later.',
      );
    }

    // 400 Bad Request - business rules (ClinetException), validation, etc.
    throw ApiClientException(
      parsed ?? 'Request could not be completed. Please try again.',
    );
  }

  Map<String, String> createHeaders() {
    String accesstoken = AuthProvider.accesstoken ?? "";

    String basicAuth = "Bearer $accesstoken";

    var headers = {
      "Content-Type": "application/json",
      "Authorization": basicAuth
    };

    return headers;
  }

  String getQueryString(Map params,
      {String prefix = '&', bool inRecursion = false}) {
    String query = '';
    params.forEach((key, value) {
      if (inRecursion) {
        if (key is int) {
          key = '[$key]';
        } else if (value is List || value is Map) {
          key = '.$key';
        } else {
          key = '.$key';
        }
      }
      if (value is String || value is int || value is double || value is bool) {
        var encoded = value;
        if (value is String) {
          encoded = Uri.encodeComponent(value);
        }
        query += '$prefix$key=$encoded';
      } else if (value is DateTime) {
        query += '$prefix$key=${value.toIso8601String()}';
      } else if (value is List || value is Map) {
        if (value is List) value = value.asMap();
        value.forEach((k, v) {
          query +=
              getQueryString({k: v}, prefix: '$prefix$key', inRecursion: true);
        });
      }
    });
    return query;
  }
}
