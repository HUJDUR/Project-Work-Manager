import '../models/truck_load.dart';
import 'base_provider.dart';

class TruckLoadProvider extends BaseProvider<TruckLoad> {
  TruckLoadProvider() : super('TruckLoad');

  @override
  TruckLoad fromJson(data) => TruckLoad.fromJson(data);
}
