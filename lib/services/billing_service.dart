import 'dart:math';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../models/bill_breakdown.dart';
import '../models/tariff.dart';

class BillingService {
  /// Calculates elapsed parking duration in whole minutes using integer division.
  /// Throws [InvalidTimestampException] if [exitMs] is less than [entryMs].
  static int durationMinutes(int entryMs, int exitMs) {
    if (exitMs < entryMs) {
      throw InvalidTimestampException(
        'Exit timestamp ($exitMs) cannot be earlier than entry timestamp ($entryMs).',
      );
    }
    return (exitMs - entryMs) ~/ 60000;
  }

  /// Calculates parking charge in whole rupees according to Section 17.1 rules.
  static int calculateCharge(int durationMinutes, TariffSettings tariff) {
    if (durationMinutes <= tariff.graceMinutes) {
      return 0;
    }
    final extra = max(0, durationMinutes - 60);
    final hours = tariff.roundingRule == AppConstants.roundingStartedHour
        ? (extra + 59) ~/ 60
        : extra ~/ 60;
    return tariff.firstHourRate + hours * tariff.additionalHourRate;
  }

  /// Produces a complete breakdown of the billing calculation.
  static BillBreakdown calculateBreakdown(int durationMinutes, TariffSettings tariff) {
    if (durationMinutes <= tariff.graceMinutes) {
      return BillBreakdown.zero(
        durationMinutes: durationMinutes,
        graceApplied: true,
      );
    }

    final extra = max(0, durationMinutes - 60);
    final hours = tariff.roundingRule == AppConstants.roundingStartedHour
        ? (extra + 59) ~/ 60
        : extra ~/ 60;
    final additionalCharge = hours * tariff.additionalHourRate;
    final total = tariff.firstHourRate + additionalCharge;

    return BillBreakdown(
      durationMinutes: durationMinutes,
      graceApplied: false,
      firstHourCharge: tariff.firstHourRate,
      additionalHours: hours,
      additionalHourRate: tariff.additionalHourRate,
      additionalCharge: additionalCharge,
      total: total,
    );
  }

  /// Reconstructs breakdown from stored snapshot and duration for receipts.
  static BillBreakdown rebuildBreakdown(
    int durationMinutes,
    String? snapshotJson,
    int storedAmount,
  ) {
    if (snapshotJson == null || snapshotJson.isEmpty) {
      return BillBreakdown(
        durationMinutes: durationMinutes,
        graceApplied: storedAmount == 0,
        firstHourCharge: storedAmount,
        additionalHours: 0,
        additionalHourRate: 0,
        additionalCharge: 0,
        total: storedAmount,
      );
    }

    try {
      final tariff = TariffSettings.fromSnapshotJson(snapshotJson);
      final calculated = calculateBreakdown(durationMinutes, tariff);
      // Ensure stored amount remains authority
      if (calculated.total != storedAmount) {
        return BillBreakdown(
          durationMinutes: durationMinutes,
          graceApplied: storedAmount == 0,
          firstHourCharge: calculated.firstHourCharge,
          additionalHours: calculated.additionalHours,
          additionalHourRate: calculated.additionalHourRate,
          additionalCharge: storedAmount - calculated.firstHourCharge,
          total: storedAmount,
        );
      }
      return calculated;
    } catch (_) {
      return BillBreakdown(
        durationMinutes: durationMinutes,
        graceApplied: storedAmount == 0,
        firstHourCharge: storedAmount,
        additionalHours: 0,
        additionalHourRate: 0,
        additionalCharge: 0,
        total: storedAmount,
      );
    }
  }
}
