class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);

  @override
  String toString() => 'DatabaseException: $message';
}

class IngestException implements Exception {
  final String message;
  IngestException(this.message);

  @override
  String toString() => 'IngestException: $message';
}
