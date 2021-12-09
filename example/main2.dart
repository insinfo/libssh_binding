import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:libssh_binding/libssh_binding.dart';

import 'dart:ffi';
import 'package:path/path.dart' as path;

void callback(Pointer<Utf8> ptr) {
  print('in callback ${ptr.toDartString()}');
}

void main(List<String> args) {
  var libraryPath = path.join(Directory.current.path, 'libssh_compiled', 'pscp.dll');
  final dll = DynamicLibrary.open(libraryPath);
  var pscp = PscpBinding(dll);

  //pscp -pw Ins257257 isaque.neves@192.168.133.13:/home/isaque.neves/go1.11.4.linux-amd64.tar.gz ./go1.11.4.linux-amd64.tar.gz

  final myStrings = [
    'PSCP', //appname
    '-pw', //no interative pass
    'Ins257257', //pass
    'isaque.neves@192.168.133.13:/home/isaque.neves/go1.11.4.linux-amd64.tar.gz2', //remote source file
    'go1.11.4.linux-amd64.tar.gz' //target local file
  ];
  final myPointers = myStrings.map((v) => v.toNativeUtf8().cast<Int8>()).toList();
  final pointerPointer = malloc<Pointer<Int8>>(myStrings.length);
  for (int i = 0; i < myStrings.length; i++) {
    pointerPointer[i] = myPointers[i];
  }
  //argc será o número de strings apontadas por argv. Isso será (na prática) 1 mais o número de argumentos,
  //visto que virtualmente todas as implementações irão preceder o nome do programa ao array.
  /*
  argc 5
argv D:\MyDartProjects\fsbackup\libssh_binding\putty\windows\VS2012\x64\Release\pscp.exe
argv -pw
argv Ins257257
argv isaque.neves@192.168.133.13:/home/isaque.neves/go1.11.4.linux-amd64.tar.gz
argv go1.11.4.linux-amd64.tar.gz
 */
//"stderror.txt".toNativeUtf8()
  int ret = pscp.pscp_main(5, pointerPointer, Pointer.fromFunction<stat_callback>(callback), nullptr);
  print('ret $ret');
}
