/// One row of the workers table: an account with its role name resolved and,
/// for shop-floor workers, the operations they are qualified for. The ids ride
/// along so the details form can prefill without fetching the account again.
class WorkerRow {
  const WorkerRow({
    required this.id,
    required this.name,
    required this.surname,
    required this.initials,
    required this.email,
    required this.username,
    required this.roleId,
    required this.roleName,
    required this.isActive,
    required this.operations,
    required this.operationIds,
    this.phoneNumber,
  });

  final int id;
  final String name;
  final String surname;
  final String initials;
  final String email;
  final String username;
  final int roleId;

  /// Administrator, Manager or Worker.
  final String roleName;

  final bool isActive;

  /// Operation names from `UserOperations`; empty for office staff.
  final List<String> operations;

  /// The same qualifications as ids, for the details form's checkboxes.
  final List<int> operationIds;

  final String? phoneNumber;

  String get fullName => '$name $surname'.trim();
}
