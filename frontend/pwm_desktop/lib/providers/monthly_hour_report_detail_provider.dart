import '../models/monthly_hour_report_detail.dart';
import 'base_provider.dart';

class MonthlyHourReportDetailProvider extends BaseProvider<MonthlyHourReportDetail> {
  MonthlyHourReportDetailProvider() : super('MonthlyHourReportDetail');

  @override
  MonthlyHourReportDetail fromJson(data) => MonthlyHourReportDetail.fromJson(data);
}
