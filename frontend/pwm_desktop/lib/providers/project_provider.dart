import '../models/project.dart';
import 'base_provider.dart';

class ProjectProvider extends BaseProvider<Project> {
  ProjectProvider() : super('Project');

  @override
  Project fromJson(data) => Project.fromJson(data);
}
