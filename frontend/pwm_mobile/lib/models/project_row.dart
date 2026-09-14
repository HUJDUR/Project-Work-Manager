import 'project.dart';
import 'project_priority.dart';

/// One project as the list draws it: the row plus the names its ids stand for,
/// resolved from the small lookup tables the screen reads once.
///
/// Carries the `Project` itself as well, so opening a row fills the detail
/// screen without a second fetch — the same bargain the desktop's `ProjectRow`
/// strikes.
///
/// It deliberately does **not** carry the customer: who ordered the job is the
/// office's business, not the shop floor's. Where it goes is
/// `ProjectsProvider.deliveryAddressOf`.
class ProjectRow {
  const ProjectRow({
    required this.project,
    required this.statusName,
    required this.categoryName,
  });

  final Project project;
  final String statusName;
  final String categoryName;

  int get id => project.id;

  /// "26-015 - Staircase module", the way both apps write a project.
  String get displayName => project.code.isEmpty
      ? project.name
      : '${project.code} - ${project.name}';

  ProjectPriority get priority => project.priorityLevel;

  double get weight => project.weight;

  DateTime? get deliveryDate => project.deliveryDate;

  DateTime? get productionStartDate => project.productionStartDate;
}
