/// The transport status life cycle, mirrored from the API's own
/// `pwm.Services.Business.TruckLoadStatusRules` the same way
/// `ProjectStatusRules` already mirrors the Project one. The server
/// re-checks every jump independently on `PATCH /TruckLoad/{id}/Status` -
/// this copy only decides which action buttons the overview screen offers
/// and which fields the edit form leaves open, so a stale click still comes
/// back as a refused request rather than a wrong one.
abstract final class TruckLoadStatusRules {
  static const String ordered = 'Ordered';
  static const String delivered = 'Delivered';
  static const String finished = 'Finished';
  static const String rejected = 'Rejected';

  /// Everything but Notes and Price - only while still Ordered.
  static bool canEditGeneralFields(String status) => status == ordered;

  /// Price is only ever hand-edited while Delivered.
  static bool canEditPrice(String status) => status == delivered;

  /// Cargo can only be added, changed or removed while still Ordered - and
  /// only once the load has been saved once, never during creation.
  static bool canEditCargo(String status) => status == ordered;

  /// The statuses [current] may move to next.
  static Set<String> allowedNext(String current) => switch (current) {
        ordered => {delivered, rejected},
        delivered => {finished},
        _ => {},
      };
}
