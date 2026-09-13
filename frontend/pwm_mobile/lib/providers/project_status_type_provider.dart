import '../models/project_status_type.dart';
import 'base_provider.dart';

class ProjectStatusTypeProvider extends BaseProvider<ProjectStatusType> {
  ProjectStatusTypeProvider() : super('ProjectStatusType');

  @override
  ProjectStatusType fromJson(data) => ProjectStatusType.fromJson(data);
}
