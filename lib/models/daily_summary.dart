class DashboardMetrics {
  final int todayCollection;
  final int activeVehicles;
  final int entriesToday;
  final int exitsToday;
  final int capacity;

  const DashboardMetrics({
    required this.todayCollection,
    required this.activeVehicles,
    required this.entriesToday,
    required this.exitsToday,
    required this.capacity,
  });

  factory DashboardMetrics.empty([int capacity = 50]) {
    return DashboardMetrics(
      todayCollection: 0,
      activeVehicles: 0,
      entriesToday: 0,
      exitsToday: 0,
      capacity: capacity,
    );
  }

  int get occupancyPercentage =>
      capacity > 0 ? ((activeVehicles * 100) / capacity).round() : 0;

  bool get isOverCapacity => activeVehicles > capacity;
}

class ReportSummary {
  final int completedCount;
  final int totalBilled;
  final int totalCollected;
  final int totalUnpaid;
  final List<DailyReportRow> dailyRows;

  const ReportSummary({
    required this.completedCount,
    required this.totalBilled,
    required this.totalCollected,
    required this.totalUnpaid,
    required this.dailyRows,
  });

  factory ReportSummary.empty() {
    return const ReportSummary(
      completedCount: 0,
      totalBilled: 0,
      totalCollected: 0,
      totalUnpaid: 0,
      dailyRows: [],
    );
  }
}

class DailyReportRow {
  final String dateString; // e.g. "16 Oct 2026"
  final int exitsCount;
  final int totalBilled;
  final int totalCollected;
  final int totalUnpaid;

  const DailyReportRow({
    required this.dateString,
    required this.exitsCount,
    required this.totalBilled,
    required this.totalCollected,
    required this.totalUnpaid,
  });
}
