import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark_ai/core/constants.dart';
import 'package:smartpark_ai/core/exceptions.dart';
import 'package:smartpark_ai/models/tariff.dart';
import 'package:smartpark_ai/services/billing_service.dart';

void main() {
  group('BillingService - Duration Calculation', () {
    test('Exit equals entry returns 0 minutes', () {
      const ts = 1773489000000;
      expect(BillingService.durationMinutes(ts, ts), 0);
    });

    test('Exit earlier than entry throws InvalidTimestampException', () {
      const entry = 1773489000000;
      const exit = 1773488999999;
      expect(
        () => BillingService.durationMinutes(entry, exit),
        throwsA(isA<InvalidTimestampException>()),
      );
    });

    test('Real overnight case (2026-03-14 22:30 to 2026-03-15 07:10) gives 520 minutes', () {
      final entry = DateTime(2026, 3, 14, 22, 30);
      final exit = DateTime(2026, 3, 15, 7, 10);
      final duration = BillingService.durationMinutes(
        entry.millisecondsSinceEpoch,
        exit.millisecondsSinceEpoch,
      );
      expect(duration, 520);
    });
  });

  group('BillingService - Section 17.1 Test Vectors', () {
    final startedHourTariff = TariffSettings(
      id: 1,
      firstHourRate: 30,
      additionalHourRate: 20,
      graceMinutes: 10,
      roundingRule: AppConstants.roundingStartedHour,
      capacity: 50,
      updatedAt: 0,
    );

    final fullHourTariff = TariffSettings(
      id: 1,
      firstHourRate: 30,
      additionalHourRate: 20,
      graceMinutes: 10,
      roundingRule: AppConstants.roundingFullHour,
      capacity: 50,
      updatedAt: 0,
    );

    // Vector table from Section 17.1
    final vectors = [
      {'duration': 0, 'started': 0, 'full': 0, 'desc': 'Instant exit'},
      {'duration': 10, 'started': 0, 'full': 0, 'desc': 'Exactly at grace'},
      {'duration': 11, 'started': 30, 'full': 30, 'desc': 'Just over grace'},
      {'duration': 60, 'started': 30, 'full': 30, 'desc': 'Exactly one hour'},
      {'duration': 61, 'started': 50, 'full': 30, 'desc': 'One hour plus one minute'},
      {'duration': 119, 'started': 50, 'full': 30, 'desc': 'Just under two hours'},
      {'duration': 120, 'started': 50, 'full': 50, 'desc': 'Exactly two hours'},
      {'duration': 121, 'started': 70, 'full': 50, 'desc': 'Two hours plus one minute'},
      {'duration': 145, 'started': 70, 'full': 50, 'desc': 'Worked example in Section 5'},
      {'duration': 520, 'started': 190, 'full': 170, 'desc': 'Overnight 22:30 to 07:10 next day'},
      {'duration': 1441, 'started': 510, 'full': 490, 'desc': '24 h plus one minute'},
    ];

    for (final v in vectors) {
      final duration = v['duration'] as int;
      final expectedStarted = v['started'] as int;
      final expectedFull = v['full'] as int;
      final desc = v['desc'] as String;

      test('Duration $duration min ($desc) - STARTED_HOUR: ₹$expectedStarted', () {
        final charge = BillingService.calculateCharge(duration, startedHourTariff);
        expect(charge, expectedStarted);

        final breakdown = BillingService.calculateBreakdown(duration, startedHourTariff);
        expect(breakdown.total, expectedStarted);
      });

      test('Duration $duration min ($desc) - FULL_HOUR: ₹$expectedFull', () {
        final charge = BillingService.calculateCharge(duration, fullHourTariff);
        expect(charge, expectedFull);

        final breakdown = BillingService.calculateBreakdown(duration, fullHourTariff);
        expect(breakdown.total, expectedFull);
      });
    }
  });
}
