/// A structured error from the Wavelength API. The server always returns
/// `{ error: { code, message } }`, and `message` is written to be shown to the
/// user directly, so screens can surface it without translating codes.
class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  factory ApiException.network() => ApiException(
        code: 'network_unreachable',
        message: "Can't reach Wavelength. Check your connection and try again.",
      );

  @override
  String toString() => 'ApiException($code): $message';
}
