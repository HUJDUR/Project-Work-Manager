import '../models/user_operation.dart';
import 'base_provider.dart';

class UserOperationProvider extends BaseProvider<UserOperation> {
  UserOperationProvider() : super('UserOperation');

  @override
  UserOperation fromJson(data) => UserOperation.fromJson(data);
}
