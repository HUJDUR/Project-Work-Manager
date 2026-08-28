import '../models/activity_log_type.dart';
import 'base_provider.dart';

class ActivityLogTypeProvider extends BaseProvider<ActivityLogType> {
  ActivityLogTypeProvider() : super('ActivityLogType');

  @override
  ActivityLogType fromJson(data) => ActivityLogType.fromJson(data);
}
