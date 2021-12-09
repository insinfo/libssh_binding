import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:libssh_binding/src/numeral_system_converter.dart';

Pointer<Void> stringToNativeVoid(String str, {Allocator allocator = calloc}) {
  final units = utf8.encode(str);
  final Pointer<Uint8> result = allocator<Uint8>(units.length + 1);
  final Uint8List nativeString = result.asTypedList(units.length + 1);
  nativeString.setAll(0, units);
  nativeString[units.length] = 0;
  return result.cast();
}

Pointer<Utf8> stringToNativeChar(String str, {Allocator allocator = calloc}) {
  final units = utf8.encode(str);
  final Pointer<Uint8> result = allocator<Uint8>(units.length + 1);
  final Uint8List nativeString = result.asTypedList(units.length + 1);
  nativeString.setAll(0, units);
  nativeString[units.length] = 0;
  return result.cast();
}

Pointer<Int8> stringToNativeInt8(String str, {Allocator allocator = calloc}) {
  final units = utf8.encode(str);
  final Pointer<Uint8> result = allocator<Uint8>(units.length + 1);
  final Uint8List nativeString = result.asTypedList(units.length + 1);
  nativeString.setAll(0, units);
  nativeString[units.length] = 0;
  return result.cast();
}

String nativeInt8ToString(Pointer<Int8> pointer, {allowMalformed: true}) {
  var ptrName = pointer.cast<Utf8>();
  final ptrNameCodeUnits = pointer.cast<Uint8>();
  var list = ptrNameCodeUnits.asTypedList(ptrName.length);
  return utf8.decode(list, allowMalformed: allowMalformed);
}

Uint8List nativeInt8ToCodeUnits(Pointer<Int8> pointer) {
  var ptrName = pointer.cast<Utf8>();
  final ptrNameCodeUnits = pointer.cast<Uint8>();
  var list = ptrNameCodeUnits.asTypedList(ptrName.length);
  return list;
}

Uint8List nativeInt8ToUint8List(Pointer<Int8> pointer) {
  var ptrName = pointer.cast<Utf8>();
  final ptrNameCodeUnits = pointer.cast<Uint8>();
  var list = ptrNameCodeUnits.asTypedList(ptrName.length);
  return list;
}

/// Sanitize-filename removes the following:
/// Control characters (0x00–0x1f and 0x80–0x9f)
/// Reserved characters (/, ?, <, >, \, :, *, |, and ")
/// Unix reserved filenames (. and ..)
/// Trailing periods and spaces (for Windows)
/// Windows reserved filenames (CON, PRN, AUX, NUL, COM1, COM2, COM3, COM4, COM5, COM6, COM7, COM8, COM9, LPT1, LPT2, LPT3, LPT4, LPT5, LPT6, LPT7, LPT8, and LPT9)
String sanitizeFilename(String input, [replacement = '_']) {
  var illegalRe = RegExp(r'[\/\?<>\\:\*\|"]', multiLine: true);
  var controlRe = RegExp(r'[\x00-\x1f\x80-\x9f]', multiLine: true);
  var reservedRe = RegExp(r'^\.+$');
  var windowsReservedRe = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$', caseSensitive: false);
  // var windowsTrailingRe = RegExp(r'[\. ]+$');

  //╟O caractere invalido

  var sanitized = input
      .replaceAll('�', replacement)
      .replaceAll('А╟', replacement)
      .replaceAll('╟', replacement)
      .replaceAll(illegalRe, replacement)
      .replaceAll(controlRe, replacement)
      .replaceAll(reservedRe, replacement);
  //  .replaceAll(windowsReservedRe, replacement)
  // .replaceAll(windowsTrailingRe, replacement);

  if (windowsReservedRe.hasMatch(input)) {
    if (!input.contains('.')) {
      sanitized = replacement + sanitized;
    }
  }

  return sanitized;
  //return truncate(sanitized, 255);
}

bool isInvalidFilename(String filename) {
  /*  
  sanitize-filename removes the following:
Control characters (0x00–0x1f and 0x80–0x9f)
Reserved characters (/, ?, <, >, \, :, *, |, and ")
Unix reserved filenames (. and ..)
Trailing periods and spaces (for Windows)
Windows reserved filenames (CON, PRN, AUX, NUL, COM1, COM2, COM3, COM4, COM5, COM6, COM7, COM8, COM9, LPT1, LPT2, LPT3, LPT4, LPT5, LPT6, LPT7, LPT8, and LPT9)
 */
//[\/\?<>\\:\*\|"]
  var rg1 = RegExp(r'[\/\?<>\\:\*\|"]', multiLine: true);

  // forbidden characters  / : * ? " < > |
  // var rg2 = RegExp(r'^.'); // cannot start with dot (.)
  var rg3 = RegExp(r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$',
      caseSensitive: false, multiLine: true); //i; // forbidden file names

  //var result = false;
  //╟O
  if (filename.indexOf('╟') != -1) {
    print('╟O $filename');
    return true;
  }

  if (rg1.hasMatch(filename)) {
    print('rg1 $filename');
    return true;
  }
  if (rg3.hasMatch(filename)) {
    print('rg3 $filename');
    return true;
  }

  return false;
}

bool isUft8MalformedStringPointer(Pointer<Int8> pointer) {
  try {
    var ptrName = pointer.cast<Utf8>();
    final ptrNameCodeUnits = pointer.cast<Uint8>();
    var list = ptrNameCodeUnits.asTypedList(ptrName.length);
    utf8.decode(list);
    return false;
  } catch (e) {
    return true;
  }
}

String uint8ListToString(Uint8List list, {allowMalformed: true}) {
  return utf8.decode(list, allowMalformed: allowMalformed);
}

Uint8List stringToUint8ListTo(String str) {
  return Uint8List.fromList(utf8.encode(str));
}

/// combine/concatenate two Uint8List
Uint8List concatUint8List(List<Uint8List> lists) {
  var bytesBuilder = BytesBuilder();
  lists.forEach((l) {
    bytesBuilder.add(l);
  });
  return bytesBuilder.toBytes();
}

dynamic permToCct(String $permissions) {
  var $mode = 0;
  if ($permissions[0] == '1') $mode += 01000;
  if ($permissions[0] == '2') $mode += 02000;
  if ($permissions[0] == '3') $mode += 03000;
  if ($permissions[0] == '4') $mode += 04000;
  if ($permissions[0] == '5') $mode += 05000;
  if ($permissions[0] == '6') $mode += 06000;
  if ($permissions[0] == '7') $mode += 07000;

  if ($permissions[1] == '1') $mode += 0100;
  if ($permissions[1] == '2') $mode += 0200;
  if ($permissions[1] == '3') $mode += 0300;
  if ($permissions[1] == '4') $mode += 0400;
  if ($permissions[1] == '5') $mode += 0500;
  if ($permissions[1] == '6') $mode += 0600;
  if ($permissions[1] == '7') $mode += 0700;

  if ($permissions[2] == '1') $mode += 010;
  if ($permissions[2] == '2') $mode += 020;
  if ($permissions[2] == '3') $mode += 030;
  if ($permissions[2] == '4') $mode += 040;
  if ($permissions[2] == '5') $mode += 050;
  if ($permissions[2] == '6') $mode += 060;
  if ($permissions[2] == '7') $mode += 070;

  if ($permissions[3] == '1') $mode += 01;
  if ($permissions[3] == '2') $mode += 02;
  if ($permissions[3] == '3') $mode += 03;
  if ($permissions[3] == '4') $mode += 04;
  if ($permissions[3] == '5') $mode += 05;
  if ($permissions[3] == '6') $mode += 06;
  if ($permissions[3] == '7') $mode += 07;

  return ($mode);
}

/// ex: stringPermissionToOctal('-rwxrwxrwx') => 777
/// [value] input '-rwxrwxrwx' => 777
String stringPermissionToOctal(String value, {bool withType = false}) {
  // drwxr-xr-x
  // skip first d
  // go through remaining in sets of 3
  var output = '';
  var grouping = 0;
  int permission = 0;
  var combinedPermission = 0;
  var fileType = '';
  var charPosition = 1;
  for (var i = 0; i < value.length; i++) {
    var alpha = value[i]; //charCodeAt

    // leading '-', ie. files, not directories
    if (i == 0 && alpha == '-') {
      grouping = 0;
      if (withType) {
        fileType = 'File: ';
      }
      continue;
    }

    // If first char entered is 'd' we're dealing with a directory
    if (i == 0 && alpha == 'd') {
      grouping = 0;
      if (withType) {
        fileType = 'Directory: ';
      }
      continue;
    }

    // Valid characters entered
    if (i >= 1 && (alpha.allMatches('[rwx-]').toList().isEmpty == true)) {
      return "Invalid";
    }

    // update character position validator when user starts with read
    if (i == 0 && alpha == 'r') {
      charPosition = 0;
    }

    // char positions matter drwx-rxw-x
    if ((i == charPosition || i == (charPosition + 3) || i == (charPosition + 6)) &&
        (alpha.allMatches('[r-]').toList().isEmpty == true)) {
      return "Invalid";
    }
    if ((i == (charPosition + 1) || i == (charPosition + 4) || i == (charPosition + 7)) &&
        (alpha.allMatches('[w-]').toList().isEmpty == true)) {
      return "Invalid";
    }
    if ((i == (charPosition + 2) || i == (charPosition + 5) || i == (charPosition + 8)) &&
        (alpha.allMatches('[x-]').toList().isEmpty == true)) {
      return "Invalid";
    }

    switch (alpha) {
      case 'r':
        permission = 4;
        grouping++;
        break;
      case 'w':
        permission = 2;
        grouping++;
        break;
      case 'x':
        permission = 1;
        grouping++;
        break;
      case '-':
        permission = 0;
        grouping++;
        break;
      default:
      //permission = "Invalid";
    }

    combinedPermission += permission;

    // Process in groups of three, then reset and continue to the next batch
    if (grouping % 3 == 0) {
      output = '$output$combinedPermission';
      grouping = 0;
      combinedPermission = 0;
      permission = 0;
    }
  }
  return fileType + output;
}

/// input Ex: 511  out: 777 => rwxrwxrwx
/// [type] file | dir | link
String intToPermissionString(int intPermission, {String type = 'file', bool withType = true}) {
  //lrwxrwxrwx
  //0777 = -rwxrwxrwx
  //drwxr-xr-x 755 bancoDeEmpregos
  //lrwxrwxrwx 777 /etc/systemd/system/php7.3-fpm.service
  //-rwxrwxrwx 777 /var/www/html/teste.txt
  // 7 = rwx
//  6 = rw-
//  4 = r--
//  3 = -wx
//  2 = -w-
//  1 = --x
  var result = '';

  //int r = 4, w = 2, x = 1, hifen = 0;
  var octal = NumeralSystemConverter.decimalToOctal2(intPermission);
  for (var i = 0; i < octal.length; i++) {
    var permission = '';
    switch (octal[i]) {
      case '7':
        permission = 'rwx';
        break;
      case '6':
        permission = 'rw-';
        break;
      case '5':
        permission = 'r-x';
        break;
      case '4':
        permission = 'r--';
        break;
      case '3':
        permission = '-wx';
        break;
      case '2':
        permission = '-w-';
        break;
      case '1':
        permission = '--x';
        break;
      case '0':
        permission = '---';
        break;
      case '':
        permission = '';
        break;
      default:
        permission = 'Invalid';
    }
    result += permission;
  }

  var tp = "${type.startsWith('f') ? '-' : type.startsWith('d') ? 'd' : 'l'}";

  result = withType ? '$tp$result' : result;

  return result;
}

Pointer<Void> intToNativeVoid(int number) {
  final ptr = calloc.allocate<Int32>(sizeOf<Int32>());
  ptr.value = number;
  return ptr.cast();
}

Pointer<Int8> uint8ListToPointerInt8(Uint8List units, {Allocator allocator = calloc}) {
  /*final pointer = allocator<Uint8>(list.length);
  for (int i = 0; i < list.length; i++) {
    pointer[i] = list[i];
  }
  return pointer.cast<Int8>();*/
  /* final units = utf8.encode(this);
    final Pointer<Uint8> result = allocator<Uint8>(units.length + 1);
    final Uint8List nativeString = result.asTypedList(units.length + 1);
    nativeString.setAll(0, units);
    nativeString[units.length] = 0;
    return result.cast();*/

  final pointer = allocator<Uint8>(units.length + 1); //blob
  final nativeString = pointer.asTypedList(units.length + 1); //blobBytes
  nativeString.setAll(0, units);
  nativeString[units.length] = 0;
  return pointer.cast();
}

Future writeAndFlush(IOSink sink, object) {
  return sink.addStream((StreamController<List<int>>(sync: true)
        ..add(utf8.encode(object.toString()))
        ..close())
      .stream);
}

extension Uint8ListBlobConversion on Uint8List {
  /// Allocates a pointer filled with the Uint8List data.
  Pointer<Uint8> allocatePointer() {
    final blob = calloc<Uint8>(length);
    final blobBytes = blob.asTypedList(length);
    blobBytes.setAll(0, this);
    return blob;
  }
}
