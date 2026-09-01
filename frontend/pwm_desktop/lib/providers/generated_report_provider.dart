import '../models/generated_report.dart';
import 'base_provider.dart';

class GeneratedReportProvider extends BaseProvider<GeneratedReport> {
  GeneratedReportProvider() : super('GeneratedReport');

  @override
  GeneratedReport fromJson(data) => GeneratedReport.fromJson(data);
}
