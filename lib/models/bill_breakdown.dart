/// Holds transparent billing calculation components
class BillBreakdown {
  final int durationMinutes;
  final bool graceApplied;
  final int firstHourCharge;
  final int additionalHours;
  final int additionalHourRate;
  final int additionalCharge;
  final int total;

  const BillBreakdown({
    required this.durationMinutes,
    required this.graceApplied,
    required this.firstHourCharge,
    required this.additionalHours,
    required this.additionalHourRate,
    required this.additionalCharge,
    required this.total,
  });

  factory BillBreakdown.zero({required int durationMinutes, required bool graceApplied}) {
    return BillBreakdown(
      durationMinutes: durationMinutes,
      graceApplied: graceApplied,
      firstHourCharge: 0,
      additionalHours: 0,
      additionalHourRate: 0,
      additionalCharge: 0,
      total: 0,
    );
  }
}
