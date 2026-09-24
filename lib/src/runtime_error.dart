/// A structured failure at the Dart/Zig boundary.
final class NativeException implements Exception {
  /// Creates a failure, optionally associated with an operation and request.
  const NativeException(
    this.code,
    this.message, {
    this.operation,
    this.requestId,
  });

  /// Machine-readable category, such as `busy`, `closed`, or `cancelled`.
  final String code;

  /// Human-readable failure detail; not a stable parsing format.
  final String message;

  /// Application route, when the failure belongs to a known operation.
  final int? operation;

  /// Session-local request identifier, if native admission occurred.
  final int? requestId;
  @override
  String toString() =>
      'NativeException($code, operation=$operation, request=$requestId): $message';
}
