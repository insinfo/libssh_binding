///
class LibsshIncompleteFileException implements Exception {
  LibsshIncompleteFileException([this.error = 'Incomplete file exception!']);
  final dynamic error;

  StackTrace? stackTrace;

  String get message => (error?.toString() ?? '');

  @override
  String toString() {
    var msg = 'LibsshIncompleteFileException: $message';
    if (stackTrace != null) {
      msg += '\n$stackTrace';
    }
    return msg;
  }
}
