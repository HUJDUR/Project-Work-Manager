import '../models/truck_load_status_type.dart';
import 'base_provider.dart';

class TruckLoadStatusTypeProvider extends BaseProvider<TruckLoadStatusType> {
  TruckLoadStatusTypeProvider() : super('TruckLoadStatusType');

  @override
  TruckLoadStatusType fromJson(data) => TruckLoadStatusType.fromJson(data);
}
