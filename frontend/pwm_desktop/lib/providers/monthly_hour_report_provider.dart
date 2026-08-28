import '../models/monthly_hour_report.dart';
import 'base_provider.dart';

class MonthlyHourReportProvider extends BaseProvider<MonthlyHourReport> {
  MonthlyHourReportProvider() : super('MonthlyHourReport');

  @override
  MonthlyHourReport fromJson(data) => MonthlyHourReport.fromJson(data);
}
