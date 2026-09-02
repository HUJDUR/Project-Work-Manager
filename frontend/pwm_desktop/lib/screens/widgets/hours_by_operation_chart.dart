import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/dashboard_data.dart';
import 'panel.dart';

class HoursByOperationChart extends StatelessWidget {
  const HoursByOperationChart({
    super.key,
    required this.slices,
    required this.windowDays,
  });

  final List<ChartSlice> slices;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Hours by operation',
      subtitle: 'Share of work over the last $windowDays days',
      child: slices.isEmpty
          ? EmptyPanelMessage(message: 'No work has been booked in this period.')
          : _buildChart(),
    );
  }

  Widget _buildChart() {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 52,
              sections: [
                for (var index = 0; index < slices.length; index++)
                  PieChartSectionData(
                    value: slices[index].value,
                    color: AppColors.seriesAt(index),
                    radius: 34,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: _Legend(slices: slices, total: total),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.slices, required this.total});

  final List<ChartSlice> slices;
  final double total;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: slices.length,
      itemBuilder: (context, index) {
        final slice = slices[index];
        final share = total == 0 ? 0.0 : slice.value / total * 100;

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.seriesAt(index),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  slice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${share.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 56,
                child: Text(
                  formatHours(slice.value),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
