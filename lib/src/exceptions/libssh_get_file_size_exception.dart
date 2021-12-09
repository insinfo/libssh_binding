class LibsshGetFileSizeException implements Exception {
  LibsshGetFileSizeException([this.error = 'Get File Size Exception!']);
  final dynamic error;

  StackTrace? stackTrace;

  String get message => (error?.toString() ?? '');

  @override
  String toString() {
    var msg = 'LibsshGetFileSizeException: $message';
    if (stackTrace != null) {
      msg += '\n$stackTrace';
    }
    return msg;
  }
}
