import 'package:flutter/foundation.dart';
import '../models/daily_summary.dart';
import '../models/parking_session.dart';
import '../models/tariff.dart';
import '../services/parking_service.dart';

class ParkingProvider extends ChangeNotifier {
  final ParkingService parkingService;

  int _revision = 0;
  int get revision => _revision;

  // Selected tab index in home shell
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  // Pre-filled plate for Exit screen (e.g., when tapped from Active Parking)
  String? _prefilledExitPlate;
  String? get prefilledExitPlate => _prefilledExitPlate;

  ParkingProvider({required this.parkingService});

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  void openExitWithPlate(String plate) {
    _prefilledExitPlate = plate;
    _currentTabIndex = 2; // Exit tab
    notifyListeners();
  }

  void clearPrefilledExitPlate() {
    _prefilledExitPlate = null;
  }

  void _bumpRevision() {
    _revision++;
    notifyListeners();
  }

  Future<ParkingSession> recordEntry({
    required String rawPlate,
    required String category,
    int? entryTimeMs,
  }) async {
    final session = await parkingService.recordEntry(
      rawPlate: rawPlate,
      category: category,
      entryTimeMs: entryTimeMs,
    );
    _bumpRevision();
    return session;
  }

  Future<ParkingExitPreview> previewExit({
    required String rawPlate,
    int? exitTimeMs,
  }) async {
    return await parkingService.previewExit(
      rawPlate: rawPlate,
      exitTimeMs: exitTimeMs,
    );
  }

  Future<ParkingSession> confirmExit({
    required ParkingExitPreview preview,
    required String paymentMethod,
    required bool isPaid,
  }) async {
    final session = await parkingService.confirmExit(
      preview: preview,
      paymentMethod: paymentMethod,
      isPaid: isPaid,
    );
    _bumpRevision();
    return session;
  }

  Future<void> markPaymentAsPaid({
    required int sessionId,
    required String paymentMethod,
  }) async {
    await parkingService.markPaymentAsPaid(
      sessionId: sessionId,
      paymentMethod: paymentMethod,
    );
    _bumpRevision();
  }

  Future<DashboardMetrics> getDashboardMetrics() async {
    return await parkingService.getDashboardMetrics();
  }

  Future<List<ParkingSession>> getActiveVehicles({String? query}) async {
    return await parkingService.getActiveVehicles(query: query);
  }

  Future<List<ParkingSession>> getHistory({
    String? plateQuery,
    int? fromMs,
    int? toMs,
    int limit = 500,
  }) async {
    return await parkingService.getHistory(
      plateQuery: plateQuery,
      fromMs: fromMs,
      toMs: toMs,
      limit: limit,
    );
  }

  Future<ReportSummary> getReports({
    required int fromMs,
    required int toMs,
  }) async {
    return await parkingService.getReports(fromMs: fromMs, toMs: toMs);
  }

  Future<TariffSettings> getTariff() async {
    return await parkingService.getTariff();
  }

  Future<void> updateTariff(TariffSettings tariff) async {
    await parkingService.updateTariff(tariff);
    _bumpRevision();
  }

  Future<ParkingSession?> getSessionById(int id) async {
    return await parkingService.getSessionById(id);
  }
}
