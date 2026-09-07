import 'package:flutter/material.dart';

class SummaryMetric {
  const SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
}

class ChartSlice {
  const ChartSlice({required this.label, required this.value, this.shortLabel});

  final String label;
  final double value;

  /// A stand-in for [label] where there is no room for it — a project's code.
  final String? shortLabel;

  /// What a cramped axis shows: the short form when there is one, else the
  /// full label. The tooltip always shows [label].
  String get axisLabel =>
      shortLabel == null || shortLabel!.isEmpty ? label : shortLabel!;
}

class WorkEntry {
  const WorkEntry({
    required this.workerName,
    required this.workerInitials,
    required this.projectName,
    required this.operationName,
    required this.hours,
    required this.startedAt,
  });

  final String workerName;
  final String workerInitials;
  final String projectName;
  final String operationName;
  final double hours;
  final DateTime startedAt;
}

class TransportEntry {
  const TransportEntry({
    required this.driverName,
    required this.vehicleRegistration,
    required this.carrierName,
    required this.loadDate,
    required this.netWeight,
  });

  final String driverName;
  final String vehicleRegistration;
  final String carrierName;
  final DateTime loadDate;
  final double netWeight;
}

class ActivityEntry {
  const ActivityEntry({
    required this.title,
    required this.actorName,
    required this.date,
  });

  final String title;
  final String actorName;
  final DateTime date;
}

class DashboardData {
  const DashboardData({
    required this.metrics,
    required this.hoursByProject,
    required this.hoursByOperation,
    required this.recentWork,
    required this.recentTransports,
    required this.recentActivity,
    required this.windowDays,
  });

  final List<SummaryMetric> metrics;
  final List<ChartSlice> hoursByProject;
  final List<ChartSlice> hoursByOperation;
  final List<WorkEntry> recentWork;
  final List<TransportEntry> recentTransports;
  final List<ActivityEntry> recentActivity;

  final int windowDays;
}
