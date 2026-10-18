import 'package:intl/intl.dart';

class AppFormatters {
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _localDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _csvDateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Whole rupees integer formatted as ₹X
  static String formatCurrency(int amount) {
    return '₹$amount';
  }

  /// Display timestamp in device local time as "dd MMM yyyy, hh:mm a"
  static String formatDateTime(int? epochMs) {
    if (epochMs == null) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();
    return _dateTimeFormat.format(dt);
  }

  /// Date only: "dd MMM yyyy"
  static String formatDate(int? epochMs) {
    if (epochMs == null) return 'N/A';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();
    return _localDateFormat.format(dt);
  }

  /// CSV export timestamp in device local time: "yyyy-MM-dd HH:mm"
  static String formatCsvDateTime(int? epochMs) {
    if (epochMs == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();
    return _csvDateTimeFormat.format(dt);
  }

  /// Formats minutes into human-readable duration, e.g., "2h 25m" or "45m"
  static String formatDuration(int minutes) {
    if (minutes < 0) return '0m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) {
      return '${remainingMinutes}m';
    } else if (remainingMinutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${remainingMinutes}m';
    }
  }

  /// Receipt number in SP-000123 style
  static String formatReceiptNumber(int id) {
    return 'SP-${id.toString().padLeft(6, '0')}';
  }

  /// Calculates start of day (local midnight) in UTC epoch milliseconds
  static int startOfTodayMs() {
    final now = DateTime.now();
    final localMidnight = DateTime(now.year, now.month, now.day);
    return localMidnight.toUtc().millisecondsSinceEpoch;
  }

  /// Calculates end of day (next local midnight) in UTC epoch milliseconds
  static int endOfTodayMs() {
    final now = DateTime.now();
    final nextLocalMidnight = DateTime(now.year, now.month, now.day + 1);
    return nextLocalMidnight.toUtc().millisecondsSinceEpoch;
  }

  /// Calculates start of day N days ago in UTC epoch milliseconds
  static int startOfDaysAgoMs(int days) {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day - days);
    return startDay.toUtc().millisecondsSinceEpoch;
  }
}
