import '../models/operation_type.dart';
import 'base_provider.dart';

class OperationTypeProvider extends BaseProvider<OperationType> {
  OperationTypeProvider() : super('OperationType');

  @override
  OperationType fromJson(data) => OperationType.fromJson(data);
}
