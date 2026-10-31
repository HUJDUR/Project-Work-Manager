import '../models/notification_type.dart';
import 'base_provider.dart';

class NotificationTypeProvider extends BaseProvider<NotificationType> {
  NotificationTypeProvider() : super('NotificationType');

  @override
  NotificationType fromJson(data) => NotificationType.fromJson(data);
}
