///Erro ao receber dados do arquivo
class LibsshReceivingFileDataException implements Exception {
  LibsshReceivingFileDataException([this.error = 'Error receiving file data!']);
  final dynamic error;

  StackTrace? stackTrace;

  String get message => (error?.toString() ?? '');

  @override
  String toString() {
    var msg = 'LibsshReceivingFileDataException: $message';
    if (stackTrace != null) {
      msg += '\n$stackTrace';
    }
    return msg;
  }
}
