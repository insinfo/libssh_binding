///
class LibsshScpAcceptRequestException implements Exception {
  LibsshScpAcceptRequestException(
      [this.error = 'Error on Scp Accept Request!']);
  final dynamic error;

  StackTrace? stackTrace;

  String get message => (error?.toString() ?? '');

  @override
  String toString() {
    var msg = 'LibsshScpAcceptRequestException: $message';
    if (stackTrace != null) {
      msg += '\n$stackTrace';
    }
    return msg;
  }
}
