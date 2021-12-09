import 'dart:io';

import 'package:libssh_binding/libssh_binding.dart';
import 'package:path/path.dart' as path;

void main() async {
  final libssh = LibsshWrapper('localhost',
      username: 'user', password: 'pass', port: 22, verbosity: false);
  libssh.connect();
  final start = DateTime.now();

  ///var/www/html/portal2018_invadido.tar.gz
  //download file via SCP
  /*await libssh.scpDownloadFileTo('/home/isaque.neves/go1.11.4.linux-amd64.tar.gz',
      path.join(Directory.current.path, 'go1.11.4.linux-amd64.tar.gz'), callbackStats: (total, loaded) {
    //var progress = ((loaded / total) * 100).round();
    //stdout.write('\r');
    //stdout.write('\r[${List.filled(((progress / 10) * 4).round(), '=').join()}] $progress%');
  });*/

  await libssh.scpDownloadDirectory('/var/www/html/portalPmro',
      path.join(Directory.current.path, 'download'));

  /*var re = libssh.execCommandSync('cd /var/www; ls -l');
  print(re);*/

  /*var re = libssh.sftpListDir('/var/www');
  print(re.join('\r\n'));*/

  //var re = libssh.execCommandsInShell(['cd /var/www', 'ls -l']);
  //print(re.join(''));
  /* await libssh.sftpDownloadFileTo(my_ssh_session, '/home/isaque.neves/go1.11.4.linux-amd64.tar.gz',
      path.join(Directory.current.path, 'go1.11.4.linux-amd64.tar.gz'));*/

  /*await libssh.sftpCopyLocalFileToRemote(
      my_ssh_session, path.join(Directory.current.path, 'teste.mp4'), '/home/isaque.neves/teste.mp4');*/
  //sleep(Duration(seconds: 20));

  //print(path.join(Directory.current.path, 'go1.11.4.linux-amd64.tar.gz'));
  /*var sftp = libssh.initSftp(my_ssh_session);
  for (var i = 0; i < 10; i++) {
    
    await libssh.sftpDownloadFileTo(my_ssh_session, '/home/isaque.neves/go1.11.4.linux-amd64.tar.gz',
        path.join(Directory.current.path, 'go1.11.4.linux-amd64.tar.gz'),
        inSftp: sftp);
  }*/

  print('\r\n${DateTime.now().difference(start)}');
  libssh.dispose();
  exit(0);
}
