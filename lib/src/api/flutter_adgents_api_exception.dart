class FlutterAdgentsApiException implements Exception {
  FlutterAdgentsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'FlutterAdgentsApiException($statusCode): $message';
}
