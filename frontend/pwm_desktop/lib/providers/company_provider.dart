import '../models/company.dart';
import 'base_provider.dart';

class CompanyProvider extends BaseProvider<Company> {
  CompanyProvider() : super('Company');

  @override
  Company fromJson(data) => Company.fromJson(data);
}
