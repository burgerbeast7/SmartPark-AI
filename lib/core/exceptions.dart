/// Typed domain exceptions for SmartPark AI
/// Each exception maps to a user-friendly plain-language message.
library;

class DuplicateActiveSessionException implements Exception {
  final String plate;
  final int entryTime;

  DuplicateActiveSessionException({
    required this.plate,
    required this.entryTime,
  });

  @override
  String toString() =>
      'Vehicle $plate is already parked (active session since entry).';
}

class NoActiveSessionException implements Exception {
  final String plate;

  NoActiveSessionException(this.plate);

  @override
  String toString() => 'No active parking session found for $plate.';
}

class AlreadyCompletedException implements Exception {
  final String plate;

  AlreadyCompletedException(this.plate);

  @override
  String toString() =>
      'Parking session for $plate has already been completed.';
}

class InvalidTimestampException implements Exception {
  final String message;

  InvalidTimestampException([this.message = 'Exit time cannot be earlier than entry time.']);

  @override
  String toString() => message;
}

class InvalidPlateException implements Exception {
  final String message;

  InvalidPlateException([this.message = 'Plate number must be between 4 and 12 characters.']);

  @override
  String toString() => message;
}

class OcrException implements Exception {
  final String message;

  OcrException([this.message = 'Failed to process optical character recognition.']);

  @override
  String toString() => message;
}
