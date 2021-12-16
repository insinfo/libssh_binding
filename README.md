### Dart Binding to libssh version 0.9.6

binding and high-level wrapper on top of libssh - The SSH library! libssh is a multiplatform C library implementing the SSHv2 protocol on client and server side. With libssh, you can remotely execute programs, transfer files, use a secure and transparent tunnel https://www.libssh.org

##### linux (Debin/Ubuntu)

```
# install dart 2.14
sudo apt-get update
sudo apt-get install apt-transport-https
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
sudo apt-get update
sudo apt-get install dart=2.14*

# install libssh
sudo apt show libssh-4
sudo apt install libssh-4
# check
ldconfig -p | grep libssh
/lib/x86_64-linux-gnu/libssh.so.4
libssh.so.4
```

##### example of high level on Ubuntu 20


```dart
void main() async {
  var libraryPath = path.join('/lib/x86_64-linux-gnu/', 'libssh.so.4');
  print('libraryPath $libraryPath');
  final dll = DynamicLibrary.open(libraryPath);

  final libssh = LibsshWrapper('192.168.3.4',
      inDll: dll,
      username: 'isaque',
      password: 'pass',
      port: 22,
      verbosity: true);
  libssh.connect();
  final start = DateTime.now();

 
  await libssh.scpDownloadDirectory('/var/www/html/portalPmro',
      path.join(Directory.current.path, 'download'));
  
  print('\r\n${DateTime.now().difference(start)}');
  libssh.dispose();
  exit(0);
}

```

##### example of low level on Windows

```dart
import 'dart:io';
import 'package:libssh_binding/libssh_binding.dart';
import 'package:libssh_binding/src/extensions/sftp_extension.dart';
import 'dart:ffi' as ffi;
import 'package:path/path.dart' as path;

void main() async {
  // Open the dynamic library
  var libraryPath = path.join(Directory.current.path, 'libssh_compiled', 'ssh.dll');
  final dll = ffi.DynamicLibrary.open(libraryPath);
  var libssh = Libssh(dll);

  var host = "localhost";
  var port = 22;
  var password = "pass";
  var username = "root";

  // Abra a sessão e define as opções
  var my_ssh_session = libssh.ssh_new();
  libssh.ssh_options_set(my_ssh_session, ssh_options_e.SSH_OPTIONS_HOST, stringToNativeVoid(host));
  libssh.ssh_options_set(my_ssh_session, ssh_options_e.SSH_OPTIONS_PORT, intToNativeVoid(port));
  //libssh.ssh_options_set(my_ssh_session, ssh_options_e.SSH_OPTIONS_LOG_VERBOSITY, intToNativeVoid(SSH_LOG_PROTOCOL));
  libssh.ssh_options_set(my_ssh_session, ssh_options_e.SSH_OPTIONS_USER, stringToNativeVoid(username));
  // Conecte-se ao servidor
  var rc = libssh.ssh_connect(my_ssh_session);
  if (rc != SSH_OK) {
    print('Error connecting to host: $host\n');
  }

  rc = libssh.ssh_userauth_password(my_ssh_session, stringToNativeInt8(username), stringToNativeInt8(password));
  if (rc != ssh_auth_e.SSH_AUTH_SUCCESS) {
    var error = libssh.ssh_get_error(my_ssh_session.cast());
    print("Error authenticating with password:$error\n");
    //ssh_disconnect(my_ssh_session);
    //ssh_free(my_ssh_session);
  }
  String resp = '';
  // resp = libssh.execCommand(my_ssh_session, 'ls -l');
  //print("$resp");
  /*resp = libssh.execCommand(my_ssh_session, 'cd /var/www/dart && ls -l');
  print("$resp");*/

  /*resp = libssh.scpReadFileAsString(my_ssh_session, '/home/isaque.neves/teste.txt');
  print('$resp');*/

  /*await libssh.scpDownloadFileTo(
      my_ssh_session, '/home/isaque.neves/teste.txt', path.join(Directory.current.path, 'teste.txt'));*/


  /*await libssh.sftpCopyLocalFileToRemote(
      my_ssh_session, path.join(Directory.current.path, 'teste.mp4'), '/home/isaque.neves/teste.mp4');*/


  await libssh.sftpDownloadFileTo(my_ssh_session, '/home/isaque.neves/teste.mp4', path.join(Directory.current.path, 'teste.mp4'));

  libssh.ssh_disconnect(my_ssh_session);
  libssh.ssh_free(my_ssh_session);

  exit(0);
}

```
##### example of high level on Windows

```dart
import 'package:libssh_binding/libssh_binding.dart';

void main() {
  final libssh = LibsshWrapper('localhost', username: 'root', password: 'pass', port: 22);
  libssh.connect();
  final start = DateTime.now();


  //download file via SCP
  /*await libssh.scpDownloadFileTo('/home/isaque.neves/go1.11.4.linux-amd64.tar.gz',
      path.join(Directory.current.path, 'go1.11.4.linux-amd64.tar.gz'), callbackStats: (total, loaded) {
    var progress = ((loaded / total) * 100).round();
    stdout.write('\r');
    stdout.write('\r[${List.filled(((progress / 10) * 4).round(), '=').join()}] $progress%');
  });*/

  //execute command
  var re = libssh.execCommandSync('cd /var/www; ls -l');
  print(re);

  //execute command in shell
  //var re = libssh.execCommandsInShell(['cd /var/www', 'ls -l']);
  //print(re.join(''));

  //download file via SFTP
  /* await libssh.sftpDownloadFileTo(my_ssh_session, '/home/isaque.neves/go1.11.4.linux-amd64.tar.gz',
      path.join(Directory.current.path, 'go1.11.4.linux-amd64.tar.gz'));*/

 //download directory recursive
  await libssh.scpDownloadDirectory('/var/www',
      path.join(Directory.current.path, 'download'));

  print('${DateTime.now().difference(start)}');
  libssh.dispose();
}

```
<!-- 

dart run ffigen --config  ffigen.yaml
go1.11.4.linux-amd64.tar.gz 120MB file
dart run --observe --pause-isolates-on-start .\example\main.dart
Measure-Command {pscp -pw Ins257257 isaque.neves@192.168.133.13:/home/isaque.neves/go1.11.4.linux-amd64.tar.gz ./go1.11.4.linux-amd64.tar.gz }

git filter-branch --tree-filter 'rm -rf libssh_binding/libssh_c_wrapper/x64/Release/go1.11.4.linux-amd64.tar.gz' HEAD

git filter-branch -f --tree-filter 'rm -f /path/to/file' HEAD --all

 perf record -g dart --generate-perf-events-symbols main.dart

 perf report --no-children -i perf.data
-->



if you want to compile libssh for android see this link [Compiling libssh for Android](https://egorovandreyrm.com/compiling-libssh-for-android-with-boringssl/)
if you need it for ios see this link [libssh2 for ios,](https://github.com/Frugghi/iSSH2) it's not for libssh, it's for libssh2 but possibly the hints should be for libssh too

