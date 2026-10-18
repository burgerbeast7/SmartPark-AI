class Payment {
  final int? id;
  final int sessionId;
  final int amount;
  final String paymentMethod; // 'CASH', 'UPI', 'OTHER'
  final String paymentStatus; // 'UNPAID', 'PAID'
  final int? paidAt;

  const Payment({
    this.id,
    required this.sessionId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paidAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      amount: map['amount'] as int,
      paymentMethod: map['payment_method'] as String,
      paymentStatus: map['payment_status'] as String,
      paidAt: map['paid_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'paid_at': paidAt,
    };
  }

  Payment copyWith({
    int? id,
    int? sessionId,
    int? amount,
    String? paymentMethod,
    String? paymentStatus,
    int? paidAt,
  }) {
    return Payment(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
