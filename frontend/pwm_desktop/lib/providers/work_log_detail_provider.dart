import '../models/work_log_detail.dart';
import 'base_provider.dart';

class WorkLogDetailProvider extends BaseProvider<WorkLogDetail> {
  WorkLogDetailProvider() : super('WorkLogDetail');

  @override
  WorkLogDetail fromJson(data) => WorkLogDetail.fromJson(data);
}
