import '../models/report_type_lookup.dart';
import 'base_provider.dart';

class ReportTypeProvider extends BaseProvider<ReportTypeLookup> {
  ReportTypeProvider() : super('ReportType');

  @override
  ReportTypeLookup fromJson(data) => ReportTypeLookup.fromJson(data);
}
