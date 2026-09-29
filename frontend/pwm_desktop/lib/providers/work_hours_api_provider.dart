import '../models/work_hours_entry.dart';
import 'base_provider.dart';

/// `GET /WorkLogDetail/Hours` - the Work Hours screen's rows, joined, split into
/// regular and overtime, and filtered by the API. Read-only: writes go through
/// the plain `WorkLog`/`WorkLogDetail` endpoints.
class WorkHoursApiProvider extends BaseProvider<WorkHoursEntry> {
  WorkHoursApiProvider() : super('WorkLogDetail/Hours');

  @override
  WorkHoursEntry fromJson(dynamic data) =>
      WorkHoursEntry.fromJson(data as Map<String, dynamic>);
}
