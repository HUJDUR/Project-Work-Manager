import '../models/notification.dart';
import 'base_provider.dart';

class NotificationProvider extends BaseProvider<Notification> {
  NotificationProvider() : super('Notification');

  @override
  Notification fromJson(data) => Notification.fromJson(data);
}
