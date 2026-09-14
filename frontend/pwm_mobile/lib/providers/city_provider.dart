import '../models/city.dart';
import 'base_provider.dart';

class CityProvider extends BaseProvider<City> {
  CityProvider() : super('City');

  @override
  City fromJson(data) => City.fromJson(data);
}
