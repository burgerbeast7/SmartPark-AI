import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants.dart';
import '../../core/exceptions.dart';
import '../../core/formatters.dart';
import '../../models/daily_summary.dart';
import '../../models/parking_session.dart';
import '../../models/payment.dart';

class ParkingRepository {
  final Database db;

  ParkingRepository(this.db);

  /// Inserts a new ACTIVE parking session in a transaction.
  /// Throws [DuplicateActiveSessionException] if an active session already exists for the plate.
  Future<ParkingSession> createEntrySession({
    required String plateNumber,
    required String category,
    required int entryTime,
  }) async {
    return await db.transaction<ParkingSession>((txn) async {
      // 1. Pre-check for duplicate active session to provide friendly message with entry time
      final existing = await txn.query(
        'parking_sessions',
        where: 'plate_number = ? AND status = ?',
        whereArgs: [plateNumber, AppConstants.statusActive],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final existingEntryTime = existing.first['entry_time'] as int;
        throw DuplicateActiveSessionException(
          plate: plateNumber,
          entryTime: existingEntryTime,
        );
      }

      // 2. Insert ACTIVE session
      try {
        final id = await txn.insert('parking_sessions', {
          'plate_number': plateNumber,
          'category': category,
          'entry_time': entryTime,
          'exit_time': null,
          'duration_minutes': null,
          'amount': null,
          'status': AppConstants.statusActive,
          'tariff_snapshot': null,
        });

        return ParkingSession(
          id: id,
          plateNumber: plateNumber,
          category: category,
          entryTime: entryTime,
          status: AppConstants.statusActive,
        );
      } catch (e) {
        // Enforced by ux_active_plate unique index as well
        if (e is DatabaseException && e.isUniqueConstraintError()) {
          throw DuplicateActiveSessionException(
            plate: plateNumber,
            entryTime: entryTime,
          );
        }
        rethrow;
      }
    });
  }

  /// Finds the single ACTIVE session for a normalized plate.
  Future<ParkingSession?> getActiveSessionByPlate(String plateNumber) async {
    final rows = await db.query(
      'parking_sessions',
      where: 'plate_number = ? AND status = ?',
      whereArgs: [plateNumber, AppConstants.statusActive],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ParkingSession.fromMap(rows.first);
  }

  /// Lists all active parking sessions, optionally filtered by plate substring.
  Future<List<ParkingSession>> getActiveSessions({String? query}) async {
    String? whereClause = 'status = ?';
    List<dynamic> whereArgs = [AppConstants.statusActive];

    if (query != null && query.trim().isNotEmpty) {
      whereClause += ' AND plate_number LIKE ?';
      whereArgs.add('%${query.trim().toUpperCase()}%');
    }

    final rows = await db.query(
      'parking_sessions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'entry_time DESC',
    );

    return rows.map((r) => ParkingSession.fromMap(r)).toList();
  }

  /// Atomically completes an active parking session and inserts the payment row.
  /// Throws [AlreadyCompletedException] if the row is no longer active.
  Future<ParkingSession> completeExitSession({
    required int sessionId,
    required String plateNumber,
    required String category,
    required int entryTime,
    required int exitTime,
    required int durationMinutes,
    required int amount,
    required String tariffSnapshot,
    required String paymentMethod,
    required String paymentStatus,
    required int? paidAt,
  }) async {
    return await db.transaction<ParkingSession>((txn) async {
      // 1. Conditional update to guarantee atomicity and prevent double processing
      final updatedRows = await txn.update(
        'parking_sessions',
        {
          'exit_time': exitTime,
          'duration_minutes': durationMinutes,
          'amount': amount,
          'status': AppConstants.statusCompleted,
          'tariff_snapshot': tariffSnapshot,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [sessionId, AppConstants.statusActive],
      );

      if (updatedRows != 1) {
        throw AlreadyCompletedException(plateNumber);
      }

      // 2. Insert payment row
      final paymentId = await txn.insert('payments', {
        'session_id': sessionId,
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'paid_at': paidAt,
      });

      final payment = Payment(
        id: paymentId,
        sessionId: sessionId,
        amount: amount,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        paidAt: paidAt,
      );

      return ParkingSession(
        id: sessionId,
        plateNumber: plateNumber,
        category: category,
        entryTime: entryTime,
        exitTime: exitTime,
        durationMinutes: durationMinutes,
        amount: amount,
        status: AppConstants.statusCompleted,
        tariffSnapshot: tariffSnapshot,
        payment: payment,
      );
    });
  }

  /// Marks an UNPAID payment as PAID from the Receipt screen.
  Future<void> markPaymentAsPaid({
    required int sessionId,
    required String paymentMethod,
    required int paidAt,
  }) async {
    await db.transaction((txn) async {
      final count = await txn.update(
        'payments',
        {
          'payment_method': paymentMethod,
          'payment_status': AppConstants.paymentStatusPaid,
          'paid_at': paidAt,
        },
        where: 'session_id = ? AND payment_status = ?',
        whereArgs: [sessionId, AppConstants.paymentStatusUnpaid],
      );

      if (count == 0) {
        throw StateError('Payment is either already paid or session does not exist.');
      }
    });
  }

  /// Retrieves a session by its ID, joining its payment record if completed.
  Future<ParkingSession?> getSessionById(int id) async {
    final sessionRows = await db.query(
      'parking_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (sessionRows.isEmpty) return null;

    final sessionMap = sessionRows.first;
    Payment? payment;
    final paymentRows = await db.query(
      'payments',
      where: 'session_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (paymentRows.isNotEmpty) {
      payment = Payment.fromMap(paymentRows.first);
    }

    return ParkingSession.fromMap(sessionMap, payment);
  }

  /// Queries completed sessions with optional time window and plate search (Section 18).
  Future<List<ParkingSession>> getCompletedSessions({
    String? plateQuery,
    int? fromMs,
    int? toMs,
    int limit = 500,
  }) async {
    String whereClause = 's.status = ?';
    List<dynamic> whereArgs = [AppConstants.statusCompleted];

    if (plateQuery != null && plateQuery.trim().isNotEmpty) {
      whereClause += ' AND s.plate_number LIKE ?';
      whereArgs.add('%${plateQuery.trim().toUpperCase()}%');
    }

    if (fromMs != null) {
      whereClause += ' AND s.exit_time >= ?';
      whereArgs.add(fromMs);
    }

    if (toMs != null) {
      whereClause += ' AND s.exit_time <= ?';
      whereArgs.add(toMs);
    }

    final query = '''
      SELECT s.*, 
             p.id AS payment_id, 
             p.amount AS payment_amount, 
             p.payment_method, 
             p.payment_status, 
             p.paid_at
      FROM parking_sessions s
      LEFT JOIN payments p ON s.id = p.session_id
      WHERE $whereClause
      ORDER BY s.exit_time DESC
      LIMIT ?
    ''';

    whereArgs.add(limit);
    final rows = await db.rawQuery(query, whereArgs);

    return rows.map((r) {
      Payment? payment;
      if (r['payment_id'] != null) {
        payment = Payment(
          id: r['payment_id'] as int,
          sessionId: r['id'] as int,
          amount: r['payment_amount'] as int,
          paymentMethod: r['payment_method'] as String,
          paymentStatus: r['payment_status'] as String,
          paidAt: r['paid_at'] as int?,
        );
      }
      return ParkingSession.fromMap(r, payment);
    }).toList();
  }

  /// Computes real-time dashboard metrics (Section 17.4 & 18).
  Future<DashboardMetrics> getDashboardMetrics() async {
    final startToday = AppFormatters.startOfTodayMs();
    final endToday = AppFormatters.endOfTodayMs();

    // 1. Capacity
    final tariffRows = await db.query('tariff_settings', where: 'id = 1', limit: 1);
    final capacity = tariffRows.isNotEmpty
        ? (tariffRows.first['capacity'] as int? ?? AppConstants.defaultCapacity)
        : AppConstants.defaultCapacity;

    // 2. Active vehicles
    final activeResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM parking_sessions WHERE status = ?',
      [AppConstants.statusActive],
    );
    final activeVehicles = Sqflite.firstIntValue(activeResult) ?? 0;

    // 3. Entries today (local midnight to next local midnight)
    final entriesResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM parking_sessions WHERE entry_time >= ? AND entry_time < ?',
      [startToday, endToday],
    );
    final entriesToday = Sqflite.firstIntValue(entriesResult) ?? 0;

    // 4. Exits today
    final exitsResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM parking_sessions WHERE status = ? AND exit_time >= ? AND exit_time < ?',
      [AppConstants.statusCompleted, startToday, endToday],
    );
    final exitsToday = Sqflite.firstIntValue(exitsResult) ?? 0;

    // 5. Collection today = sum of PAID payments with paid_at today
    final collectionResult = await db.rawQuery(
      'SELECT SUM(amount) as total FROM payments WHERE payment_status = ? AND paid_at >= ? AND paid_at < ?',
      [AppConstants.paymentStatusPaid, startToday, endToday],
    );
    final todayCollection = Sqflite.firstIntValue(collectionResult) ?? 0;

    return DashboardMetrics(
      todayCollection: todayCollection,
      activeVehicles: activeVehicles,
      entriesToday: entriesToday,
      exitsToday: exitsToday,
      capacity: capacity,
    );
  }

  /// Calculates report summary and daily totals aggregated by local date (Section 18).
  Future<ReportSummary> getReportSummary({
    required int fromMs,
    required int toMs,
  }) async {
    final sessions = await getCompletedSessions(
      fromMs: fromMs,
      toMs: toMs,
      limit: 5000,
    );

    if (sessions.isEmpty) {
      return ReportSummary.empty();
    }

    int totalBilled = 0;
    int totalCollected = 0;
    int totalUnpaid = 0;

    // Grouping by local date string
    final Map<String, List<ParkingSession>> groupedByDate = {};
    final dateFormat = DateFormat('dd MMM yyyy');

    for (final s in sessions) {
      totalBilled += s.amount ?? 0;
      final isPaid = s.payment?.paymentStatus == AppConstants.paymentStatusPaid;
      if (isPaid) {
        totalCollected += s.amount ?? 0;
      } else {
        totalUnpaid += s.amount ?? 0;
      }

      final localDateStr = dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(s.exitTime!, isUtc: true).toLocal(),
      );
      groupedByDate.putIfAbsent(localDateStr, () => []).add(s);
    }

    final dailyRows = <DailyReportRow>[];
    groupedByDate.forEach((dateStr, sessionList) {
      int dayBilled = 0;
      int dayCollected = 0;
      int dayUnpaid = 0;

      for (final s in sessionList) {
        dayBilled += s.amount ?? 0;
        if (s.payment?.paymentStatus == AppConstants.paymentStatusPaid) {
          dayCollected += s.amount ?? 0;
        } else {
          dayUnpaid += s.amount ?? 0;
        }
      }

      dailyRows.add(DailyReportRow(
        dateString: dateStr,
        exitsCount: sessionList.length,
        totalBilled: dayBilled,
        totalCollected: dayCollected,
        totalUnpaid: dayUnpaid,
      ));
    });

    return ReportSummary(
      completedCount: sessions.length,
      totalBilled: totalBilled,
      totalCollected: totalCollected,
      totalUnpaid: totalUnpaid,
      dailyRows: dailyRows,
    );
  }
}
