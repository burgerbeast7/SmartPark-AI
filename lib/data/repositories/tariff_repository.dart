import 'package:sqflite/sqflite.dart';
import '../../models/tariff.dart';

class TariffRepository {
  final Database db;

  TariffRepository(this.db);

  Future<TariffSettings> getTariff() async {
    final rows = await db.query(
      'tariff_settings',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      final defaultTariff = TariffSettings.defaultSettings();
      await db.insert('tariff_settings', defaultTariff.toMap());
      return defaultTariff;
    }
    return TariffSettings.fromMap(rows.first);
  }

  Future<void> updateTariff(TariffSettings tariff) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final map = tariff.copyWith(id: 1, updatedAt: now).toMap();
    await db.update(
      'tariff_settings',
      map,
      where: 'id = 1',
    );
  }
}
