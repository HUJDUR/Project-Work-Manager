/// How urgent a project is. Hardcoded on both sides rather than a lookup table:
/// the four levels are fixed by the business. The int is what the API stores.
enum ProjectPriority {
  low(1, 'Low'),
  medium(2, 'Medium'),
  high(3, 'High'),
  veryHigh(4, 'Very high');

  const ProjectPriority(this.value, this.label);

  final int value;
  final String label;

  /// Falls back to [medium] for a value this build does not know.
  static ProjectPriority fromValue(int? value) => ProjectPriority.values
      .firstWhere((priority) => priority.value == value, orElse: () => medium);
}
