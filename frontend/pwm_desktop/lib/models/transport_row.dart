/// One row of the transports table: a `TruckLoad` already joined to the carrier
/// and status it only carries ids for. The ids ride along so the details form
/// can prefill its dropdowns without fetching the load again.
class TransportRow {
  const TransportRow({
    required this.id,
    required this.carrierId,
    required this.carrierName,
    required this.statusId,
    required this.statusName,
    required this.loadDate,
    required this.driverName,
    required this.driverSurname,
    required this.vehicleRegistration,
    required this.emptyWeight,
    required this.fullWeight,
    this.note,
    this.price,
  });

  final int id;

  final int carrierId;
  final String carrierName;
  final int statusId;
  final String statusName;

  final DateTime loadDate;
  final String driverName;
  final String driverSurname;
  final String vehicleRegistration;

  /// Kilograms, as the API stores them.
  final double emptyWeight;
  final double fullWeight;

  final String? note;

  /// The invoice amount in EUR, once the load has been marked "Finished".
  final double? price;

  /// The mockup's Transport No. There is no such column — a load is identified
  /// by its id, and this is that id in the shape the office writes it down.
  String get transportNo => 'TR-${id.toString().padLeft(4, '0')}';

  String get driverFullName => '$driverName $driverSurname'.trim();

  /// What is actually on the truck: loaded weight less the empty vehicle.
  double get netWeight => (fullWeight - emptyWeight).clamp(0, double.infinity);
}

/// One project loaded onto a truck — a `TruckLoadDetail` with its project name
/// resolved. The details screen edits these as a list under the load itself.
class TransportLine {
  const TransportLine({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.brutoWeight,
    required this.netoWeight,
    required this.unloadPriority,
    required this.unloadColor,
  });

  /// Zero until the line has been written — a line added in the form has no row
  /// behind it yet.
  final int id;

  final int projectId;
  final String projectName;
  final double brutoWeight;
  final double netoWeight;

  /// The order the driver drops the cargo off in, and the colour it is marked
  /// with so the crew can tell the pallets apart.
  final int unloadPriority;
  final String unloadColor;

  bool get isNew => id == 0;

  TransportLine copyWith({
    int? projectId,
    String? projectName,
    double? brutoWeight,
    double? netoWeight,
    int? unloadPriority,
    String? unloadColor,
  }) =>
      TransportLine(
        id: id,
        projectId: projectId ?? this.projectId,
        projectName: projectName ?? this.projectName,
        brutoWeight: brutoWeight ?? this.brutoWeight,
        netoWeight: netoWeight ?? this.netoWeight,
        unloadPriority: unloadPriority ?? this.unloadPriority,
        unloadColor: unloadColor ?? this.unloadColor,
      );
}
