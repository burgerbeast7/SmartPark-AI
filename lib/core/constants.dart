import 'package:flutter/material.dart';

class AppConstants {
  static const String appTitle = 'SmartPark AI';
  static const Color primarySeedColor = Color(0xFF0E8C7F);

  // Vehicle Categories
  static const String categoryCar = 'CAR';
  static const String categoryBike = 'BIKE';
  static const String categoryOther = 'OTHER';
  static const List<String> categories = [categoryCar, categoryBike, categoryOther];

  // Session Statuses
  static const String statusActive = 'ACTIVE';
  static const String statusCompleted = 'COMPLETED';

  // Payment Methods
  static const String paymentMethodCash = 'CASH';
  static const String paymentMethodUpi = 'UPI';
  static const String paymentMethodOther = 'OTHER';
  static const List<String> paymentMethods = [paymentMethodCash, paymentMethodUpi, paymentMethodOther];

  // Payment Statuses
  static const String paymentStatusUnpaid = 'UNPAID';
  static const String paymentStatusPaid = 'PAID';

  // Rounding Rules
  static const String roundingStartedHour = 'STARTED_HOUR';
  static const String roundingFullHour = 'FULL_HOUR';

  // Tariff Defaults (Section 13)
  static const int defaultFirstHourRate = 30;
  static const int defaultAdditionalHourRate = 20;
  static const int defaultGraceMinutes = 10;
  static const String defaultRoundingRule = roundingStartedHour;
  static const int defaultCapacity = 50;

  // Plate Validation
  static const int minPlateLength = 4;
  static const int maxPlateLength = 12;

  // Author & Copyright Attribution
  static const String authorName = 'Kunal Chauhan';
  static const String developerCredit = 'Designed & Developed by Kunal Chauhan';
  static const String copyrightNotice = '© 2026 Kunal Chauhan. All rights reserved.';
  static const String copyrightShort = '© Kunal Chauhan';
}
