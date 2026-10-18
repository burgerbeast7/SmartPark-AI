import 'dart:convert';
import '../core/constants.dart';

class TariffSettings {
  final int id;
  final int firstHourRate;
  final int additionalHourRate;
  final int graceMinutes;
  final String roundingRule; // 'STARTED_HOUR' or 'FULL_HOUR'
  final int capacity;
  final int updatedAt;

  const TariffSettings({
    this.id = 1,
    required this.firstHourRate,
    required this.additionalHourRate,
    required this.graceMinutes,
    required this.roundingRule,
    required this.capacity,
    required this.updatedAt,
  });

  factory TariffSettings.defaultSettings() {
    return TariffSettings(
      id: 1,
      firstHourRate: AppConstants.defaultFirstHourRate,
      additionalHourRate: AppConstants.defaultAdditionalHourRate,
      graceMinutes: AppConstants.defaultGraceMinutes,
      roundingRule: AppConstants.defaultRoundingRule,
      capacity: AppConstants.defaultCapacity,
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  factory TariffSettings.fromMap(Map<String, dynamic> map) {
    return TariffSettings(
      id: map['id'] as int? ?? 1,
      firstHourRate: map['first_hour_rate'] as int,
      additionalHourRate: map['additional_hour_rate'] as int,
      graceMinutes: map['grace_minutes'] as int,
      roundingRule: map['rounding_rule'] as String,
      capacity: map['capacity'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_hour_rate': firstHourRate,
      'additional_hour_rate': additionalHourRate,
      'grace_minutes': graceMinutes,
      'rounding_rule': roundingRule,
      'capacity': capacity,
      'updated_at': updatedAt,
    };
  }

  /// JSON snapshot string stored with completed parking sessions
  String toSnapshotJson() {
    return jsonEncode({
      'first_hour_rate': firstHourRate,
      'additional_hour_rate': additionalHourRate,
      'grace_minutes': graceMinutes,
      'rounding_rule': roundingRule,
    });
  }

  factory TariffSettings.fromSnapshotJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return TariffSettings(
      id: 1,
      firstHourRate: map['first_hour_rate'] as int,
      additionalHourRate: map['additional_hour_rate'] as int,
      graceMinutes: map['grace_minutes'] as int,
      roundingRule: map['rounding_rule'] as String,
      capacity: 50,
      updatedAt: 0,
    );
  }

  TariffSettings copyWith({
    int? id,
    int? firstHourRate,
    int? additionalHourRate,
    int? graceMinutes,
    String? roundingRule,
    int? capacity,
    int? updatedAt,
  }) {
    return TariffSettings(
      id: id ?? this.id,
      firstHourRate: firstHourRate ?? this.firstHourRate,
      additionalHourRate: additionalHourRate ?? this.additionalHourRate,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      roundingRule: roundingRule ?? this.roundingRule,
      capacity: capacity ?? this.capacity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
