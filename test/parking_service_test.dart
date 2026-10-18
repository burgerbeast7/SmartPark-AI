import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smartpark_ai/core/constants.dart';
import 'package:smartpark_ai/core/exceptions.dart';
import 'package:smartpark_ai/data/app_database.dart';
import 'package:smartpark_ai/data/repositories/parking_repository.dart';
import 'package:smartpark_ai/data/repositories/tariff_repository.dart';
import 'package:smartpark_ai/services/parking_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ParkingService - In-Memory Database Tests (Section 20)', () {
    late AppDatabase appDb;
    late ParkingRepository parkingRepo;
    late TariffRepository tariffRepo;
    late ParkingService service;

    setUp(() async {
      // In-memory SQLite database
      appDb = await AppDatabase.init(
        customPath: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      parkingRepo = ParkingRepository(appDb.database);
      tariffRepo = TariffRepository(appDb.database);
      service = ParkingService(
        parkingRepository: parkingRepo,
        tariffRepository: tariffRepo,
      );
    });

    tearDown(() async {
      await appDb.close();
    });

    test('1. Entry creates one ACTIVE row', () async {
      final session = await service.recordEntry(
        rawPlate: 'DL 01 AB 1234',
        category: AppConstants.categoryCar,
        entryTimeMs: 1773489000000,
      );

      expect(session.id, isNotNull);
      expect(session.plateNumber, 'DL01AB1234');
      expect(session.category, AppConstants.categoryCar);
      expect(session.status, AppConstants.statusActive);
      expect(session.entryTime, 1773489000000);

      final activeList = await service.getActiveVehicles();
      expect(activeList.length, 1);
      expect(activeList.first.plateNumber, 'DL01AB1234');
    });

    test('2. Duplicate entry throws DuplicateActiveSessionException', () async {
      await service.recordEntry(
        rawPlate: 'DL01AB1234',
        category: AppConstants.categoryCar,
      );

      expect(
        () => service.recordEntry(
          rawPlate: 'dl 01 ab-1234',
          category: AppConstants.categoryCar,
        ),
        throwsA(isA<DuplicateActiveSessionException>()),
      );
    });

    test('3. Exit with no active session throws NoActiveSessionException', () async {
      expect(
        () => service.previewExit(rawPlate: 'UNKNOWN999'),
        throwsA(isA<NoActiveSessionException>()),
      );
    });

    test('4. Exit completes with expected amount and PAID payment', () async {
      const entryTime = 1773489000000;
      // 145 minutes later: default tariff (30 first hr + 2 extra hrs @ 20) -> ₹70
      const exitTime = entryTime + 145 * 60 * 1000;

      await service.recordEntry(
        rawPlate: 'MH12DE1432',
        category: AppConstants.categoryCar,
        entryTimeMs: entryTime,
      );

      final preview = await service.previewExit(
        rawPlate: 'MH12DE1432',
        exitTimeMs: exitTime,
      );
      expect(preview.durationMinutes, 145);
      expect(preview.breakdown.total, 70);

      final completedSession = await service.confirmExit(
        preview: preview,
        paymentMethod: AppConstants.paymentMethodCash,
        isPaid: true,
      );

      expect(completedSession.status, AppConstants.statusCompleted);
      expect(completedSession.amount, 70);
      expect(completedSession.durationMinutes, 145);
      expect(completedSession.payment?.paymentStatus, AppConstants.paymentStatusPaid);
      expect(completedSession.payment?.paymentMethod, AppConstants.paymentMethodCash);

      // Verify no longer in active list
      final activeList = await service.getActiveVehicles();
      expect(activeList.isEmpty, isTrue);
    });

    test('5. Exit completes with UNPAID payment when isPaid is false', () async {
      const entryTime = 1773489000000;
      const exitTime = entryTime + 60 * 60 * 1000; // 60 min -> ₹30

      await service.recordEntry(
        rawPlate: 'KA01AA1111',
        category: AppConstants.categoryBike,
        entryTimeMs: entryTime,
      );

      final preview = await service.previewExit(
        rawPlate: 'KA01AA1111',
        exitTimeMs: exitTime,
      );
      expect(preview.breakdown.total, 30);

      final completed = await service.confirmExit(
        preview: preview,
        paymentMethod: AppConstants.paymentMethodUpi,
        isPaid: false,
      );

      expect(completed.payment?.paymentStatus, AppConstants.paymentStatusUnpaid);
      expect(completed.payment?.paidAt, isNull);
    });

    test('6. A second exit throws AlreadyCompletedException', () async {
      const entryTime = 1773489000000;
      const exitTime = entryTime + 30 * 60 * 1000;

      await service.recordEntry(
        rawPlate: 'HR26AB0001',
        category: AppConstants.categoryCar,
        entryTimeMs: entryTime,
      );

      final preview = await service.previewExit(
        rawPlate: 'HR26AB0001',
        exitTimeMs: exitTime,
      );

      await service.confirmExit(
        preview: preview,
        paymentMethod: AppConstants.paymentMethodCash,
        isPaid: true,
      );

      // Attempt second confirmation with same preview
      expect(
        () => service.confirmExit(
          preview: preview,
          paymentMethod: AppConstants.paymentMethodCash,
          isPaid: true,
        ),
        throwsA(isA<AlreadyCompletedException>()),
      );
    });

    test('7. Changing tariff after exit leaves completed amount unchanged', () async {
      const entryTime = 1773489000000;
      const exitTime = entryTime + 120 * 60 * 1000; // 120 min -> ₹50

      await service.recordEntry(
        rawPlate: 'UP16CD5555',
        category: AppConstants.categoryCar,
        entryTimeMs: entryTime,
      );

      final preview = await service.previewExit(
        rawPlate: 'UP16CD5555',
        exitTimeMs: exitTime,
      );
      final completed = await service.confirmExit(
        preview: preview,
        paymentMethod: AppConstants.paymentMethodCash,
        isPaid: true,
      );
      expect(completed.amount, 50);

      // Change tariff significantly
      final currentTariff = await service.getTariff();
      await service.updateTariff(currentTariff.copyWith(
        firstHourRate: 100,
        additionalHourRate: 80,
      ));

      // Re-fetch completed session
      final fetched = await service.getSessionById(completed.id!);
      expect(fetched?.amount, 50);
    });

    test('8. Mark as Paid works for UNPAID session', () async {
      const entryTime = 1773489000000;
      const exitTime = entryTime + 60 * 60 * 1000;

      await service.recordEntry(
        rawPlate: 'GJ01EF8888',
        category: AppConstants.categoryCar,
        entryTimeMs: entryTime,
      );

      final preview = await service.previewExit(
        rawPlate: 'GJ01EF8888',
        exitTimeMs: exitTime,
      );
      final completed = await service.confirmExit(
        preview: preview,
        paymentMethod: AppConstants.paymentMethodOther,
        isPaid: false,
      );
      expect(completed.payment?.paymentStatus, AppConstants.paymentStatusUnpaid);

      await service.markPaymentAsPaid(
        sessionId: completed.id!,
        paymentMethod: AppConstants.paymentMethodUpi,
      );

      final updated = await service.getSessionById(completed.id!);
      expect(updated?.payment?.paymentStatus, AppConstants.paymentStatusPaid);
      expect(updated?.payment?.paymentMethod, AppConstants.paymentMethodUpi);
      expect(updated?.payment?.paidAt, isNotNull);
    });

    test('9. Dashboard counts agree with real database rows', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Active session
      await service.recordEntry(
        rawPlate: 'PB10XY0001',
        category: AppConstants.categoryCar,
        entryTimeMs: now,
      );

      // Completed PAID session
      await service.recordEntry(
        rawPlate: 'PB10XY0002',
        category: AppConstants.categoryCar,
        entryTimeMs: now - 3600000,
      );
      final prev2 = await service.previewExit(
        rawPlate: 'PB10XY0002',
        exitTimeMs: now,
      );
      await service.confirmExit(
        preview: prev2,
        paymentMethod: AppConstants.paymentMethodCash,
        isPaid: true,
      );

      final metrics = await service.getDashboardMetrics();
      expect(metrics.activeVehicles, 1);
      expect(metrics.entriesToday, 2);
      expect(metrics.exitsToday, 1);
      expect(metrics.todayCollection, prev2.breakdown.total);
    });
  });

  group('ParkingService - File Persistence Across Reopen (Section 20)', () {
    test('10. Closing and reopening file database keeps the data', () async {
      final tempDir = await Directory.systemTemp.createTemp('smartpark_test_');
      final dbPath = p.join(tempDir.path, 'persist_test.db');

      // 1. Open database, write data, close
      var db1 = await AppDatabase.init(
        customPath: dbPath,
        factory: databaseFactoryFfi,
      );
      var svc1 = ParkingService(
        parkingRepository: ParkingRepository(db1.database),
        tariffRepository: TariffRepository(db1.database),
      );

      await svc1.recordEntry(
        rawPlate: 'KA05MN9999',
        category: AppConstants.categoryCar,
        entryTimeMs: 1773489000000,
      );
      await db1.close();

      // 2. Re-open database from same file path and verify data exists
      var db2 = await AppDatabase.init(
        customPath: dbPath,
        factory: databaseFactoryFfi,
      );
      var svc2 = ParkingService(
        parkingRepository: ParkingRepository(db2.database),
        tariffRepository: TariffRepository(db2.database),
      );

      final activeList = await svc2.getActiveVehicles();
      expect(activeList.length, 1);
      expect(activeList.first.plateNumber, 'KA05MN9999');

      await db2.close();
      await tempDir.delete(recursive: true);
    });
  });
}
