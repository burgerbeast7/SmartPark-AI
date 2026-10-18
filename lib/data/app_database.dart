import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String databaseFileName = 'smartpark.db';
  static const int databaseVersion = 1;

  Database? _db;

  AppDatabase([this._db]);

  Database get database {
    if (_db == null) {
      throw StateError('Database has not been opened yet. Call init() first.');
    }
    return _db!;
  }

  /// Opens or creates the SQLite database.
  /// If [customPath] or [factory] is supplied, it is used (ideal for tests).
  static Future<AppDatabase> init({
    String? customPath,
    DatabaseFactory? factory,
  }) async {
    final String path;
    if (customPath != null) {
      path = customPath;
    } else {
      final dbFolder = await (factory != null
          ? factory.getDatabasesPath()
          : getDatabasesPath());
      path = p.join(dbFolder, databaseFileName);
    }

    final openFunc = factory != null ? factory.openDatabase : openDatabase;

    final db = await openFunc(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) async {
          // Critical: Enable foreign key constraint enforcement
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await createSchema(db);
        },
      ),
    );

    return AppDatabase(db);
  }

  static Future<void> createSchema(DatabaseExecutor db) async {
    // 1. tariff_settings table
    await db.execute('''
      CREATE TABLE tariff_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        first_hour_rate INTEGER NOT NULL CHECK (first_hour_rate >= 0),
        additional_hour_rate INTEGER NOT NULL CHECK (additional_hour_rate >= 0),
        grace_minutes INTEGER NOT NULL CHECK (grace_minutes >= 0),
        rounding_rule TEXT NOT NULL CHECK (rounding_rule IN ('STARTED_HOUR','FULL_HOUR')),
        capacity INTEGER NOT NULL CHECK (capacity >= 1),
        updated_at INTEGER NOT NULL
      );
    ''');

    // Default tariff row: id=1, 30, 20, 10, 'STARTED_HOUR', 50, now
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.rawInsert('''
      INSERT INTO tariff_settings (
        id, first_hour_rate, additional_hour_rate, grace_minutes, rounding_rule, capacity, updated_at
      ) VALUES (1, 30, 20, 10, 'STARTED_HOUR', 50, ?);
    ''', [now]);

    // 2. parking_sessions table
    await db.execute('''
      CREATE TABLE parking_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plate_number TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'CAR' CHECK (category IN ('CAR','BIKE','OTHER')),
        entry_time INTEGER NOT NULL,
        exit_time INTEGER,
        duration_minutes INTEGER,
        amount INTEGER,
        status TEXT NOT NULL CHECK (status IN ('ACTIVE','COMPLETED')),
        tariff_snapshot TEXT,
        CHECK (
          (status = 'ACTIVE' AND exit_time IS NULL AND amount IS NULL) OR
          (status = 'COMPLETED' AND exit_time IS NOT NULL AND amount IS NOT NULL
             AND duration_minutes IS NOT NULL AND tariff_snapshot IS NOT NULL
             AND exit_time >= entry_time)
        )
      );
    ''');

    // Indexes on parking_sessions
    await db.execute('''
      CREATE UNIQUE INDEX ux_active_plate ON parking_sessions(plate_number)
        WHERE status = 'ACTIVE';
    ''');
    await db.execute('''
      CREATE INDEX ix_sessions_entry ON parking_sessions(entry_time);
    ''');
    await db.execute('''
      CREATE INDEX ix_sessions_exit ON parking_sessions(exit_time);
    ''');

    // 3. payments table
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL UNIQUE
          REFERENCES parking_sessions(id) ON DELETE RESTRICT,
        amount INTEGER NOT NULL CHECK (amount >= 0),
        payment_method TEXT NOT NULL CHECK (payment_method IN ('CASH','UPI','OTHER')),
        payment_status TEXT NOT NULL CHECK (payment_status IN ('UNPAID','PAID')),
        paid_at INTEGER
      );
    ''');

    await db.execute('''
      CREATE INDEX ix_payments_paid_at ON payments(paid_at);
    ''');
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
