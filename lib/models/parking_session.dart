import 'payment.dart';

class ParkingSession {
  final int? id;
  final String plateNumber;
  final String category; // 'CAR', 'BIKE', 'OTHER'
  final int entryTime;
  final int? exitTime;
  final int? durationMinutes;
  final int? amount;
  final String status; // 'ACTIVE', 'COMPLETED'
  final String? tariffSnapshot;
  final Payment? payment;

  const ParkingSession({
    this.id,
    required this.plateNumber,
    required this.category,
    required this.entryTime,
    this.exitTime,
    this.durationMinutes,
    this.amount,
    required this.status,
    this.tariffSnapshot,
    this.payment,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';

  factory ParkingSession.fromMap(Map<String, dynamic> map, [Payment? payment]) {
    return ParkingSession(
      id: map['id'] as int?,
      plateNumber: map['plate_number'] as String,
      category: map['category'] as String? ?? 'CAR',
      entryTime: map['entry_time'] as int,
      exitTime: map['exit_time'] as int?,
      durationMinutes: map['duration_minutes'] as int?,
      amount: map['amount'] as int?,
      status: map['status'] as String,
      tariffSnapshot: map['tariff_snapshot'] as String?,
      payment: payment,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plate_number': plateNumber,
      'category': category,
      'entry_time': entryTime,
      'exit_time': exitTime,
      'duration_minutes': durationMinutes,
      'amount': amount,
      'status': status,
      'tariff_snapshot': tariffSnapshot,
    };
  }

  ParkingSession copyWith({
    int? id,
    String? plateNumber,
    String? category,
    int? entryTime,
    int? exitTime,
    int? durationMinutes,
    int? amount,
    String? status,
    String? tariffSnapshot,
    Payment? payment,
  }) {
    return ParkingSession(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      category: category ?? this.category,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      tariffSnapshot: tariffSnapshot ?? this.tariffSnapshot,
      payment: payment ?? this.payment,
    );
  }
}
