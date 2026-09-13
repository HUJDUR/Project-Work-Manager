import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import 'sparkline.dart';

/// One of the two metric cards on My Work Hours: an accent badge and a title on
/// top, the figure and its trend line underneath.
///
/// Different shape from the dashboard's `SummaryCard`, which splits one card
/// into two tiles — here each card carries a single number and its own
/// sparkline, which is what the mockup draws.
///
/// It expects a **bounded height** — it bottom-aligns its figure so a pair of
/// these line up — so put it in a row under `IntrinsicHeight` with
/// `CrossAxisAlignment.stretch`, the way `MyHoursScreen` does.
class TrendCard extends StatelessWidget {
  const TrendCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.trend,
  });

  final IconData icon;
  final String title;
  final String value;

  /// "hrs" / "projects" — the word after the figure.
  final String unit;

  final List<double> trend;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Pushes the figure to the bottom of the card. "Projects Worked On"
          // wraps to two lines where "Total Hours" does not, and without this
          // the two cards' numbers sit at different heights side by side.
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // The figure and its unit scale down **as a pair**: two of these
                // cards share the width of a phone, and "Projects Worked On"
                // leaves about 60px for "12 projects". Fitting only the number
                // would still overflow on the word after it.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        unit,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Sparkline(values: trend),
            ],
          ),
        ],
      ),
    );
  }
}
