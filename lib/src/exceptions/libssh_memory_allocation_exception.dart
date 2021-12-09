///Buffer Memory allocation error
class LibsshMemoryAllocationException implements Exception {
  LibsshMemoryAllocationException(
      [this.error = 'Buffer Memory allocation error!']);
  final dynamic error;

  StackTrace? stackTrace;

  String get message => (error?.toString() ?? '');

  @override
  String toString() {
    var msg = 'LibsshMemoryAllocationException: $message';
    if (stackTrace != null) {
      msg += '\n$stackTrace';
    }
    return msg;
  }
}
