import '../models/user_type.dart';
import 'base_provider.dart';

class UserTypeProvider extends BaseProvider<UserType> {
  UserTypeProvider() : super('UserType');

  @override
  UserType fromJson(data) => UserType.fromJson(data);
}
