import '../models/company_type.dart';
import 'base_provider.dart';

class CompanyTypeProvider extends BaseProvider<CompanyType> {
  CompanyTypeProvider() : super('CompanyType');

  @override
  CompanyType fromJson(data) => CompanyType.fromJson(data);
}
