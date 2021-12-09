///
class LibsshReceivingFileInformationException implements Exception {
  LibsshReceivingFileInformationException(
      [this.error = 'Error receiving file information!']);
  final dynamic error;

  StackTrace? stackTrace;

  String get message => (error?.toString() ?? '');

  @override
  String toString() {
    var msg = 'LibsshReceivingFileInformationException: $message';
    if (stackTrace != null) {
      msg += '\n$stackTrace';
    }
    return msg;
  }
}
