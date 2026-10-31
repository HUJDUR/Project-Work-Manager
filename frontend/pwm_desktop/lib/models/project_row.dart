import 'project_priority.dart';

/// One row of the projects table, already joined to the customer, category and
/// status the project only carries ids for. The ids ride along so the details
/// form can prefill its dropdowns without fetching the project again.
class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.name,
    required this.weight,
    required this.code,
    required this.priority,
    required this.createdByUserId,
    required this.createdByName,
    required this.customerId,
    required this.customerName,
    required this.categoryId,
    required this.categoryName,
    required this.statusId,
    required this.statusName,
    required this.createdAt,
    this.description,
    this.notes,
    this.plannedStartDate,
    this.productionStartDate,
    this.endDate,
    this.deliveryCompanyId,
    this.location,
  });

  final int id;
  final String name;

  /// The shop's own reference for the job, e.g. MU-2201.
  final String code;

  final String? description;
  final String? notes;

  /// Kilograms, as the API stores it.
  final double weight;

  final ProjectPriority priority;

  /// Who raised the project, resolved to a name for the table.
  final int createdByUserId;
  final String createdByName;

  final int customerId;
  final String customerName;
  final int categoryId;
  final String categoryName;
  final int statusId;
  final String statusName;
  final DateTime createdAt;

  /// When work was planned to start, when production actually started - null
  /// until it has - and when the project is (or was) due out.
  final DateTime? plannedStartDate;
  final DateTime? productionStartDate;
  final DateTime? endDate;

  /// The carrier taking the goods out, and where that is: the delivery
  /// company's city and country. Both null until a carrier is assigned.
  final int? deliveryCompanyId;
  final String? location;

  /// "MU-2201 - Hall roof structure", the way the shop refers to a job.
  String get displayName => '$code - $name';
}
