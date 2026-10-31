import 'dart:convert';

/// Thrown when the API returns an error body we can show to the user
/// (e.g. [ClientException] → HTTP 400 with `message` / `errors` from ExceptionFilter).
class ApiClientException implements Exception {
  ApiClientException(this.message, {this.fieldErrors = const {}});

  final String message;

  /// A validation message per request field, keyed by the form field's name
  /// (`username` for the API's `Username`), so a form can show it under the box.
  final Map<String, String> fieldErrors;

  @override
  String toString() => message;
}

/// Parses JSON error payloads from pwm.WebAPI [ExceptionFilter].
class ApiErrorParser {
  ApiErrorParser._();

  /// Prefer root `message`, then `errors.clientError`, then other error lists.
  static String? messageFromBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);

      final root = map['message'];
      if (root is String) {
        final m = root.trim();
        if (m.isNotEmpty) {
          return m;
        }
      }

      final errors = map['errors'];
      if (errors is Map) {
        final errMap = Map<String, dynamic>.from(errors);
        final parts = <String>[];

        void addKey(String key) {
          final v = errMap[key];
          parts.addAll(_messagesFromValue(v));
        }

        addKey('clientError');
        for (final key in errMap.keys) {
          if (key == 'clientError') {
            continue;
          }
          addKey(key);
        }

        final unique = parts.toSet().toList();
        if (unique.isNotEmpty) {
          return unique.join('\n');
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// The ExceptionFilter's own keys - not request fields.
  static const _generalKeys = {'clientError', 'forbidden', 'notFound', 'conflict', 'serverError', ''};

  static Map<String, String> fieldErrorsFromBody(String body) {
    try {
      final decoded = jsonDecode(body.trim());
      if (decoded is! Map || decoded['errors'] is! Map) return const {};

      return {
        for (final entry in (decoded['errors'] as Map).entries)
          if (!_generalKeys.contains(entry.key) && _messagesFromValue(entry.value).isNotEmpty)
            _fieldName(entry.key as String): _messagesFromValue(entry.value).first,
      };
    } catch (_) {
      return const {};
    }
  }

  static String _fieldName(String key) =>
      key.isEmpty ? key : key[0].toLowerCase() + key.substring(1);

  static List<String> _messagesFromValue(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? [] : [s];
    }
    return [];
  }
}
