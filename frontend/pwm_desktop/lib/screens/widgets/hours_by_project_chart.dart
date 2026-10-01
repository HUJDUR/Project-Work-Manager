import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/dashboard_data.dart';
import 'panel.dart';

class HoursByProjectChart extends StatelessWidget {
  const HoursByProjectChart({super.key, required this.slices, required this.windowDays});

  final List<ChartSlice> slices;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Hours by project',
      subtitle: 'Booked work over the last $windowDays days',
      child: slices.isEmpty
          ? EmptyPanelMessage(message: 'No work has been booked in this period.')
          : _buildChart(),
    );
  }

  Widget _buildChart() {
    final maxValue = slices.map((slice) => slice.value).reduce((a, b) => a > b ? a : b);
    // Round the axis up to a whole number of hours so the grid lines land on
    // readable values rather than on the tallest bar.
    final maxY = (maxValue * 1.2 / 10).ceil() * 10.0;
    final interval = maxY / 4;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            // The tooltip floats over the card, so it takes the palette's own
            // pair rather than textPrimary: that is near-white in dark, which
            // left white text on a white bubble.
            getTooltipColor: (_) => AppColors.tooltipSurface,
            // A rim of the text colour, not AppColors.border: in dark the
            // border is darker than the bubble and would not lift it off the card.
            tooltipBorder:
                BorderSide(color: AppColors.tooltipText.withValues(alpha: 0.18)),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            maxContentWidth: 220,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${slices[group.x].label}\n',
              TextStyle(
                color: AppColors.tooltipText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: formatHours(rod.toY),
                  style: TextStyle(
                    color: AppColors.tooltipText.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => _BarLabel(slice: slices[value.toInt()]),
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < slices.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: slices[index].value,
                  width: 26,
                  color: AppColors.seriesAt(index),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Project names are long ("Hall roof structure"), so the axis shows the
/// project's code and the full name stays in the tooltip. Splitting the name on
/// spaces used to stand in for the code, which turned "Purlin sets" into "sets".
class _BarLabel extends StatelessWidget {
  const _BarLabel({required this.slice});

  final ChartSlice slice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Tooltip(
        message: slice.label,
        child: Text(
          slice.axisLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
