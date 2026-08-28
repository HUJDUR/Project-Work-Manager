import '../models/activity_log.dart';
import 'base_provider.dart';

class ActivityLogProvider extends BaseProvider<ActivityLog> {
  ActivityLogProvider() : super('ActivityLog');

  @override
  ActivityLog fromJson(data) => ActivityLog.fromJson(data);
}
