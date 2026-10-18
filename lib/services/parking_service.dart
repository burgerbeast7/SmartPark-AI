import '../core/constants.dart';
import '../core/exceptions.dart';
import '../data/repositories/parking_repository.dart';
import '../data/repositories/tariff_repository.dart';
import '../models/bill_breakdown.dart';
import '../models/daily_summary.dart';
import '../models/parking_session.dart';
import '../models/tariff.dart';
import 'billing_service.dart';
import 'plate_service.dart';

class ParkingExitPreview {
  final ParkingSession session;
  final int exitTime;
  final int durationMinutes;
  final BillBreakdown breakdown;
  final TariffSettings tariff;

  const ParkingExitPreview({
    required this.session,
    required this.exitTime,
    required this.durationMinutes,
    required this.breakdown,
    required this.tariff,
  });
}

class ParkingService {
  final ParkingRepository parkingRepository;
  final TariffRepository tariffRepository;

  ParkingService({
    required this.parkingRepository,
    required this.tariffRepository,
  });

  /// Records a vehicle entry session after normalization and validation.
  Future<ParkingSession> recordEntry({
    required String rawPlate,
    required String category,
    int? entryTimeMs,
  }) async {
    final normalized = PlateService.normalize(rawPlate);
    final validation = PlateService.validate(normalized);
    if (!validation.isValidLength) {
      throw InvalidPlateException(
        'Plate number must be between ${AppConstants.minPlateLength} and ${AppConstants.maxPlateLength} characters.',
      );
    }

    final entryTime = entryTimeMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    return await parkingRepository.createEntrySession(
      plateNumber: normalized,
      category: category,
      entryTime: entryTime,
    );
  }

  /// Previews vehicle exit: locks exit timestamp once and computes bill breakdown.
  Future<ParkingExitPreview> previewExit({
    required String rawPlate,
    int? exitTimeMs,
  }) async {
    final normalized = PlateService.normalize(rawPlate);
    final session = await parkingRepository.getActiveSessionByPlate(normalized);
    if (session == null) {
      throw NoActiveSessionException(normalized.isEmpty ? rawPlate : normalized);
    }

    final exitTime = exitTimeMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final duration = BillingService.durationMinutes(session.entryTime, exitTime);
    final tariff = await tariffRepository.getTariff();
    final breakdown = BillingService.calculateBreakdown(duration, tariff);

    return ParkingExitPreview(
      session: session,
      exitTime: exitTime,
      durationMinutes: duration,
      breakdown: breakdown,
      tariff: tariff,
    );
  }

  /// Confirms vehicle exit in an atomic transaction.
  Future<ParkingSession> confirmExit({
    required ParkingExitPreview preview,
    required String paymentMethod,
    required bool isPaid,
  }) async {
    final session = preview.session;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final paymentStatus = isPaid ? AppConstants.paymentStatusPaid : AppConstants.paymentStatusUnpaid;
    final paidAt = isPaid ? now : null;

    return await parkingRepository.completeExitSession(
      sessionId: session.id!,
      plateNumber: session.plateNumber,
      category: session.category,
      entryTime: session.entryTime,
      exitTime: preview.exitTime,
      durationMinutes: preview.durationMinutes,
      amount: preview.breakdown.total,
      tariffSnapshot: preview.tariff.toSnapshotJson(),
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paidAt: paidAt,
    );
  }

  /// Marks an UNPAID completed session as PAID.
  Future<void> markPaymentAsPaid({
    required int sessionId,
    required String paymentMethod,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await parkingRepository.markPaymentAsPaid(
      sessionId: sessionId,
      paymentMethod: paymentMethod,
      paidAt: now,
    );
  }

  /// Fetches a single session by ID.
  Future<ParkingSession?> getSessionById(int id) async {
    return await parkingRepository.getSessionById(id);
  }

  /// Fetches active vehicles.
  Future<List<ParkingSession>> getActiveVehicles({String? query}) async {
    return await parkingRepository.getActiveSessions(query: query);
  }

  /// Fetches completed sessions for History tab.
  Future<List<ParkingSession>> getHistory({
    String? plateQuery,
    int? fromMs,
    int? toMs,
    int limit = 500,
  }) async {
    return await parkingRepository.getCompletedSessions(
      plateQuery: plateQuery,
      fromMs: fromMs,
      toMs: toMs,
      limit: limit,
    );
  }

  /// Fetches real-time dashboard metrics.
  Future<DashboardMetrics> getDashboardMetrics() async {
    return await parkingRepository.getDashboardMetrics();
  }

  /// Fetches aggregated report summary.
  Future<ReportSummary> getReports({
    required int fromMs,
    required int toMs,
  }) async {
    return await parkingRepository.getReportSummary(fromMs: fromMs, toMs: toMs);
  }

  /// Gets current tariff settings.
  Future<TariffSettings> getTariff() async {
    return await tariffRepository.getTariff();
  }

  /// Updates tariff settings.
  Future<void> updateTariff(TariffSettings tariff) async {
    await tariffRepository.updateTariff(tariff);
  }
}
