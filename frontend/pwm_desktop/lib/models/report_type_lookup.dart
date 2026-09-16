import 'package:json_annotation/json_annotation.dart';

part 'report_type_lookup.g.dart';

/// Mirrors one `ReportTypes` row - not to be confused with the `ReportType` enum
/// in `generated_report.dart`, which is which of the two reports a run was, not
/// a row of this table. The name collision is why this one is not just `ReportType`.
@JsonSerializable()
class ReportTypeLookup {
  const ReportTypeLookup({required this.id, required this.description});

  final int id;
  final String description;

  factory ReportTypeLookup.fromJson(Map<String, dynamic> json) =>
      _$ReportTypeLookupFromJson(json);

  Map<String, dynamic> toJson() => _$ReportTypeLookupToJson(this);
}
