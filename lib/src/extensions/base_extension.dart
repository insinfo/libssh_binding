import 'dart:ffi';
import 'package:libssh_binding/src/libssh_binding.dart';
import 'package:libssh_binding/src/sftp_binding.dart';

extension BaseSshExtension on LibsshBinding {
  /// abtraction for init SFTP
  Pointer<sftp_session_struct> initSftp(ssh_session session) {
    var sftp = sftp_new(session);
    if (sftp.address == nullptr.address) {
      throw Exception('Error allocating SFTP session: ${sftp_get_error(sftp)}');
    }
    //initializing SFTP session
    var rc = sftp_init(sftp);
    if (rc != SSH_OK) {
      sftp_free(sftp);
      throw Exception('Error initializing SFTP session: ${sftp_get_error(sftp)}');
    }

    return sftp;
  }
}
