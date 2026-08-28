import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
          ? const EmptyPanelMessage(message: 'No work has been booked in this period.')
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
            getTooltipColor: (_) => AppColors.textPrimary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${slices[group.x].label}\n',
              const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                  text: formatHours(rod.toY),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
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
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => _BarLabel(label: slices[value.toInt()].label),
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

/// Project names are long ("Hall roof structure MU-2201"), so the axis shows the
/// trailing code and the full name stays in the tooltip.
class _BarLabel extends StatelessWidget {
  const _BarLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final parts = label.split(' ');
    final short = parts.length > 1 ? parts.last : label;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Tooltip(
        message: label,
        child: Text(
          short,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
