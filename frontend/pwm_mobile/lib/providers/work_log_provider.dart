import '../models/work_log.dart';
import 'base_provider.dart';

class WorkLogProvider extends BaseProvider<WorkLog> {
  WorkLogProvider() : super('WorkLog');

  @override
  WorkLog fromJson(data) => WorkLog.fromJson(data);
}
