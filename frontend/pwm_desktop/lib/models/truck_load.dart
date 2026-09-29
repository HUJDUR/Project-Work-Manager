import 'package:json_annotation/json_annotation.dart';
import '../utils/sarajevo_time.dart';

part 'truck_load.g.dart';

@JsonSerializable(converters: [ApiDateTimeConverter()])
class TruckLoad {
  const TruckLoad({
    required this.id,
    required this.transportCompanyId,
    required this.truckLoadStatusId,
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
  final int transportCompanyId;
  final int truckLoadStatusId;
  final DateTime loadDate;
  final String driverName;
  final String driverSurname;
  final String vehicleRegistration;
  final double emptyWeight;
  final double fullWeight;
  final String? note;

  /// The invoice amount in EUR, once the load has been marked "Finished" -
  /// null before that.
  final double? price;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get driverFullName => '$driverName $driverSurname'.trim();

  /// Cargo weight in kilograms.
  @JsonKey(includeFromJson: false, includeToJson: false)
  double get netWeight => (fullWeight - emptyWeight).clamp(0, double.infinity);

  factory TruckLoad.fromJson(Map<String, dynamic> json) => _$TruckLoadFromJson(json);

  Map<String, dynamic> toJson() => _$TruckLoadToJson(this);
}
