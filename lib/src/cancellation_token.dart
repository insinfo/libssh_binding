import 'dart:async';

import 'package:libssh_binding/src/exceptions/libssh_cancel_exception.dart';

/// You can cancel a request by using a cancel token.
/// One token can be shared with different requests.
/// when a token's [cancel] method invoked, all requests
/// with this token will be cancelled.
class LibsshCancelToken {
  LibsshCancelToken() {
    _completer = Completer<LibsshCancelException>();
  }

  /// If request have been canceled, save the cancel Error.
  LibsshCancelException? _cancelError;

  /// If request have been canceled, save the cancel Error.
  LibsshCancelException? get cancelError => _cancelError;

  late Completer<LibsshCancelException> _completer;

  /// whether cancelled
  bool get isCancelled => _cancelError != null;

  /// When cancelled, this future will be resolved.
  Future<LibsshCancelException> get whenCancel => _completer.future;

  /// Cancel the request
  void cancel([dynamic reason]) {
    _cancelError = LibsshCancelException(reason);
    _cancelError!.stackTrace = StackTrace.current;
    _completer.complete(_cancelError);
  }
}
