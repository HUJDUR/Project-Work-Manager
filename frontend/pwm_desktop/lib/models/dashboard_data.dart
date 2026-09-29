import '../utils/formatters.dart';
import '../utils/sarajevo_time.dart';
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

  /// `GET /Dashboard`, which does every count, sum and grouping on the server;
  /// only the wording and icons of the summary cards are decided here.
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final windowDays = json['windowDays'] as int;

    List<ChartSlice> slices(String key) => [
          for (final slice in json[key] as List)
            ChartSlice(
              label: slice['label'] as String,
              shortLabel: slice['shortLabel'] as String?,
              value: (slice['value'] as num).toDouble(),
            ),
        ];

    return DashboardData(
      windowDays: windowDays,
      metrics: [
        SummaryMetric(
          icon: Icons.schedule_outlined,
          label: 'Hours logged',
          value: formatHours((json['hoursLogged'] as num).toDouble()),
          caption: 'last $windowDays days',
        ),
        SummaryMetric(
          icon: Icons.folder_outlined,
          label: 'Active projects',
          value: formatCount(json['activeProjects'] as int),
          caption: '${json['inProduction']} in production',
        ),
        SummaryMetric(
          icon: Icons.groups_outlined,
          label: 'Workers',
          value: formatCount(json['activeWorkers'] as int),
          caption: '${json['workersWithBookings']} booked hours',
        ),
        SummaryMetric(
          icon: Icons.local_shipping_outlined,
          label: 'Transports',
          value: formatCount(json['transports'] as int),
          caption: 'last $windowDays days',
        ),
        SummaryMetric(
          icon: Icons.scale_outlined,
          label: 'Shipped weight',
          value: formatTonnes((json['shippedWeight'] as num).toDouble()),
          caption: 'last $windowDays days',
        ),
      ],
      hoursByProject: slices('hoursByProject'),
      hoursByOperation: slices('hoursByOperation'),
      recentWork: [
        for (final work in json['recentWork'] as List)
          WorkEntry(
            workerName: work['workerName'] as String,
            workerInitials: work['workerInitials'] as String,
            projectName: work['projectName'] as String,
            operationName: work['operationName'] as String,
            hours: (work['hours'] as num).toDouble(),
            startedAt: SarajevoTime.fromApi(work['startedAt'] as String),
          ),
      ],
      recentTransports: [
        for (final load in json['recentTransports'] as List)
          TransportEntry(
            driverName: load['driverName'] as String,
            vehicleRegistration: load['vehicleRegistration'] as String,
            carrierName: load['carrierName'] as String,
            loadDate: SarajevoTime.fromApi(load['loadDate'] as String),
            netWeight: (load['netWeight'] as num).toDouble(),
          ),
      ],
      recentActivity: [
        for (final activity in json['recentActivity'] as List)
          ActivityEntry(
            title: activity['title'] as String,
            actorName: activity['actorName'] as String,
            date: SarajevoTime.fromApi(activity['date'] as String),
          ),
      ],
    );
  }

  final List<SummaryMetric> metrics;
  final List<ChartSlice> hoursByProject;
  final List<ChartSlice> hoursByOperation;
  final List<WorkEntry> recentWork;
  final List<TransportEntry> recentTransports;
  final List<ActivityEntry> recentActivity;

  final int windowDays;
}
