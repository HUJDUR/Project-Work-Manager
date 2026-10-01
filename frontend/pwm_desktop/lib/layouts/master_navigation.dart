import 'package:flutter/widgets.dart';

/// What a screen inside `MasterScreen` may ask of the shell around it - a
/// switch to another sidebar destination, which a screen's own navigator
/// cannot do.
class MasterNavigation extends InheritedWidget {
  const MasterNavigation({
    super.key,
    required this.openMonthlyReport,
    required super.child,
  });

  /// Switches to Reports with the Monthly Work Hours form set to [period]'s
  /// month.
  final ValueChanged<DateTime> openMonthlyReport;

  /// Null outside the shell, e.g. in a widget test.
  static MasterNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MasterNavigation>();

  @override
  bool updateShouldNotify(MasterNavigation oldWidget) =>
      openMonthlyReport != oldWidget.openMonthlyReport;
}
