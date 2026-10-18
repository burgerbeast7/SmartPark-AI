import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';

class CsvService {
  static const String csvHeader =
      'id,plate,category,entry_time,exit_time,duration_minutes,amount,payment_status,payment_method,paid_at';

  /// Escapes a CSV field according to RFC 4180 standards.
  static String escapeField(dynamic field) {
    if (field == null) return '""';
    final str = field.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return '"$str"';
  }

  /// Converts a completed parking session to an RFC 4180 CSV row string.
  static String sessionToCsvRow(ParkingSession session) {
    return [
      escapeField(session.id),
      escapeField(session.plateNumber),
      escapeField(session.category),
      escapeField(AppFormatters.formatCsvDateTime(session.entryTime)),
      escapeField(AppFormatters.formatCsvDateTime(session.exitTime)),
      escapeField(session.durationMinutes),
      escapeField(session.amount),
      escapeField(session.payment?.paymentStatus ?? 'UNPAID'),
      escapeField(session.payment?.paymentMethod ?? ''),
      escapeField(AppFormatters.formatCsvDateTime(session.payment?.paidAt)),
    ].join(',');
  }

  /// Generates the complete CSV string for a list of completed sessions.
  static String generateCsv(List<ParkingSession> completedSessions) {
    final buffer = StringBuffer();
    buffer.writeln(csvHeader);
    for (final s in completedSessions) {
      buffer.writeln(sessionToCsvRow(s));
    }
    return buffer.toString();
  }

  /// Writes CSV content to a temporary file: smartpark_YYYYMMDD_HHmm.csv
  static Future<File> writeCsvToTempFile(List<ParkingSession> completedSessions) async {
    final csvContent = generateCsv(completedSessions);
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final timeStamp = DateFormat('yyyyMMdd_HHmm').format(now);
    final fileName = 'smartpark_$timeStamp.csv';
    final file = File(p.join(tempDir.path, fileName));
    return await file.writeAsString(csvContent);
  }
}
