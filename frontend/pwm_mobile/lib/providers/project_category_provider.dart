import '../models/project_category.dart';
import 'base_provider.dart';

class ProjectCategoryProvider extends BaseProvider<ProjectCategory> {
  ProjectCategoryProvider() : super('ProjectCategory');

  @override
  ProjectCategory fromJson(data) => ProjectCategory.fromJson(data);
}
