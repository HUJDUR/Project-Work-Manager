import '../models/truck_load_detail.dart';
import 'base_provider.dart';

class TruckLoadDetailProvider extends BaseProvider<TruckLoadDetail> {
  TruckLoadDetailProvider() : super('TruckLoadDetail');

  @override
  TruckLoadDetail fromJson(data) => TruckLoadDetail.fromJson(data);
}
