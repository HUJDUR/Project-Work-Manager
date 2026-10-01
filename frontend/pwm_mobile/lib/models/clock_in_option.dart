/// One entry in a Clock In dropdown - a project or an operation - with the label
/// the API already wrote for it ("26-015 - Staircase module", "Welding").
class ClockInOption {
  const ClockInOption({required this.id, required this.name});

  final int id;
  final String name;

  factory ClockInOption.fromJson(Map<String, dynamic> json) =>
      ClockInOption(id: json['id'] as int, name: json['name'] as String);
}
