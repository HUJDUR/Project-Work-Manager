import '../models/project_status_type.dart';

/// What the shop floor deals in.
///
/// **This app only ever shows projects that are in production.** It is the
/// production workers' app: a delivered job, a rejected quote or one on hold is
/// not something they can book time against or do anything about, so it is not
/// something they are shown. The desktop is where the office sees the whole
/// book.
///
/// Both screens that name a project go through here — Projects lists them,
/// Clock In offers them — so there is one definition of "live" rather than two
/// that can drift apart.
abstract final class ShopFloor {
  /// Matched by **name**, not id: the ids are the seeder's, the name is the
  /// business's. `ProjectStatusTypes` is a read-only lookup precisely because
  /// the C# branches on these names.
  static const String liveStatus = 'In production';

  /// The id [liveStatus] wears in this database, or null when no such status
  /// exists — a seeding problem, and the caller's cue to show nothing rather
  /// than to fall back to showing everything.
  static int? liveStatusId(Iterable<ProjectStatusType> statuses) => statuses
      .where((status) => status.name.toLowerCase() == liveStatus.toLowerCase())
      .map((status) => status.id)
      .firstOrNull;
}
