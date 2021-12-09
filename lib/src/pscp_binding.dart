// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

/// Bindings to pscp
class PscpBinding {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName) _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  PscpBinding(ffi.DynamicLibrary dynamicLibrary) : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  PscpBinding.fromLookup(ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName) lookup)
      : _lookup = lookup;

  int pscp_main(
    int argc,
    ffi.Pointer<ffi.Pointer<ffi.Int8>> argv,
    ffi.Pointer<ffi.NativeFunction<stat_callback>> callback_stats,
    ffi.Pointer<Utf8> override_stderr,
  ) {
    return _pscp_main(
      argc,
      argv,
      callback_stats,
      override_stderr,
    );
  }

  late final _pscp_main_ptr = _lookup<ffi.NativeFunction<_c_pscp_main>>('pscp_main');
  late final _dart_pscp_main _pscp_main = _pscp_main_ptr.asFunction<_dart_pscp_main>();
}

typedef stat_callback = ffi.Void Function(
  ffi.Pointer<Utf8>,
);

typedef _c_pscp_main = ffi.Int32 Function(
  ffi.Int32 argc,
  ffi.Pointer<ffi.Pointer<ffi.Int8>> argv,
  ffi.Pointer<ffi.NativeFunction<stat_callback>> callback_stats,
  ffi.Pointer<Utf8> override_stderr,
);

typedef _dart_pscp_main = int Function(
  int argc,
  ffi.Pointer<ffi.Pointer<ffi.Int8>> argv,
  ffi.Pointer<ffi.NativeFunction<stat_callback>> callback_stats,
  ffi.Pointer<Utf8> override_stderr,
);
