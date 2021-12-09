import 'dart:async';

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:libssh_binding/src/extensions/base_extension.dart';
import 'package:libssh_binding/src/fcntl.dart';
import 'package:libssh_binding/src/libssh_binding.dart';
import 'package:libssh_binding/src/models/directory_item.dart';
import 'package:libssh_binding/src/sftp_binding.dart';
import 'package:libssh_binding/src/stat.dart';
import 'package:libssh_binding/src/utils.dart';
import '../constants.dart';

extension SftpExtension on LibsshBinding {
  /// create Directory on the remote computer
  /// [fullPath] example => "/home/helloworld"
  void sftpCreateDirectory(ssh_session session, String fullRemotePath,
      {Allocator allocator = calloc}) {
    final path = fullRemotePath.toNativeUtf8();
    final sftp = initSftp(session);

    var rc = sftp_mkdir(sftp, path.cast(), S_IRWXU);
    if (rc != SSH_OK) {
      if (sftp_get_error(sftp) != SSH_FX_FILE_ALREADY_EXISTS) {
        throw Exception(
            'Can\'t create directory: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
      }
    }
    allocator.free(path);
    sftp_free(sftp);
  }

  /// Listing the contents of a directory
  /// [allowMalformed] allow Malformed utf8 file and directory name
  List<DirectoryItem> sftpListDir(ssh_session session, String fullRemotePath,
      {Allocator allocator = calloc, bool allowMalformed = false}) {
    final path = fullRemotePath.toNativeUtf8(allocator: allocator).cast<Int8>();
    return sftpListDirFromPointer(session, path,
        allocator: allocator, allowMalformed: allowMalformed);
  }

  /// Listing the contents of a directory
  /// [allowMalformed] allow Malformed utf8 file and directory name
  List<DirectoryItem> sftpListDirFromRawPath(
      ssh_session session, Uint8List fullRemotePath,
      {Allocator allocator = calloc, bool allowMalformed = false}) {
    //print('nativePath: ${rootDirectory.nativePath}');
    /*print('nativePath Uint8List: ${fullRemotePath}');
    print('nativePath String: ${uint8ListToString(fullRemotePath)}');
    print('/var/www:${stringToUint8ListTo('/var/www')}');*/
    var path = uint8ListToPointerInt8(fullRemotePath);
    //print('nativePath pointer: ${nativeInt8ToString(path)}');

    return sftpListDirFromPointer(session, path,
        allocator: allocator, allowMalformed: allowMalformed);
  }

  /// Listing the contents of a directory
  /// [allowMalformed] allow Malformed utf8 file and directory name
  List<DirectoryItem> sftpListDirFromPointer(
      ssh_session session, Pointer<Int8> fullRemotePath,
      {Allocator allocator = calloc, bool allowMalformed = false}) {
    final sftp = initSftp(session);
    final results = <DirectoryItem>[];

    var dir = sftp_opendir(sftp, fullRemotePath);
    if (dir == nullptr) {
      allocator.free(fullRemotePath);
      sftp_free(sftp);
      throw Exception(
          'Directory not opened: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    //print("Name                       Size Perms    Owner\tGroup\n");
    sftp_attributes attributes;

    while ((attributes = sftp_readdir(sftp, dir)) != nullptr) {
      if (sftp_dir_eof(dir) == 1) {
        break;
      }
      if (attributes.ref.name == nullptr) {
        break;
      }
      //longname => drwxrwxrwx    2 www-data www-data     4096 Jun 25  2018 .ssh

      var name = nativeInt8ToString(attributes.ref.name);
      //var name = ptrName.cast<Utf8>().toDartString();
      //var longname = attributes.ref.longname.cast<Utf8>().toDartString();
      var longname = nativeInt8ToString(attributes.ref.longname);
      /* print(
          '$name  | ${attributes.ref.size} | ${attributes.ref.permissions} | ${attributes.ref.owner.cast<Utf8>().toDartString()} |' +
              '${attributes.ref.uid} |  ${attributes.ref.group.cast<Utf8>().toDartString()}  ${attributes.ref.gid}');
        */
      //var t = attributes.ref.type == 1 ? 'file' : 'directory';

      var uint8Name = nativeInt8ToUint8List(attributes.ref.name);
      var uint8RemotePt = nativeInt8ToUint8List(fullRemotePath);
      var stringRemotePt = uint8ListToString(uint8RemotePt);

      var separator = stringRemotePt.contains('/') ? '/' : '\\';

      var uint8Path =
          stringRemotePt.substring(stringRemotePt.length - 1) != separator
              ? concatUint8List([
                  uint8RemotePt,
                  Uint8List.fromList([47]), //=> '/'
                  uint8Name
                ])
              : concatUint8List([uint8RemotePt, uint8Name]);

      //var nPath = stringRemotePt.substring(stringRemotePt.length - 1) != '/' ? '$stringRemotePt/$name' : '$stringRemotePt$name';
      //print('nPath $nPath');
      var type = attributes.ref.type == 1
          ? DirectoryItemType.file
          : DirectoryItemType.directory;

      var size = attributes.ref.size;
      var path = uint8ListToString(uint8Path);

      var dirItem = DirectoryItem(
          nativePath: uint8Path,
          longname: longname,
          path: path,
          name: name,
          type: type,
          size: size,
          isSymbolicLink: attributes.ref.type == SSH_FILEXFER_TYPE_SYMLINK,
          flags: attributes.ref.flags,
          atime: attributes.ref.atime64,
          mtime: attributes.ref.mtime64,
          createtime: attributes.ref.createtime,
          permissions: attributes.ref.permissions);

      if (allowMalformed == false) {
        if (!isUft8MalformedStringPointer(attributes.ref.name)) {
          results.add(dirItem);
        }
      } else {
        results.add(dirItem);
      }

      sftp_attributes_free(attributes);
    }

    var rc = sftp_closedir(dir);
    if (rc != SSH_OK) {
      allocator.free(fullRemotePath);
      sftp_free(sftp);
      throw Exception(
          'Can\'t close directory: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    allocator.free(fullRemotePath);
    sftp_free(sftp);
    return results;
  }

  /// Copying a local file to the remote computer
  Future<void> sftpCopyLocalFileToRemote(
      ssh_session session, String localFilefullPath, String remoteFilefullPath,
      {Allocator allocator = calloc}) async {
    var remotePath = remoteFilefullPath.toNativeUtf8(allocator: allocator);
    var sftp = initSftp(session);
    //get remote file for writing
    int accessType = O_WRONLY | O_CREAT | O_TRUNC;
    var remoteFile = sftp_open(sftp, remotePath.cast(), accessType, S_IRWXU);
    if (remoteFile.address == nullptr.address) {
      sftp_free(sftp);
      throw Exception(
          'Can\'t open remote file for writing: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }

    //get local file
    var localFile = File(localFilefullPath);

    if (localFile.existsSync() == false) {
      sftp_free(sftp);
      throw Exception('Local File don\'t exists');
    }

    var localFileLength = localFile.lengthSync();

    var lfile = await localFile.open(mode: FileMode.read);
    int bs = MAX_XFER_BUF_SIZE; //(4 * 1024);
    int bufferSize = localFileLength > bs ? bs : localFileLength;

    final bufferNative = allocator<Uint8>(bufferSize);
    var nwritten = 0;
    //var builder = new BytesBuilder(copy: false);
    while (true) {
      var bufferDart = await lfile.read(bufferSize);
      //builder.add(bufferDart);
      if (bufferDart.length <= 0) {
        break;
      }
      bufferNative.asTypedList(bufferSize).setAll(0, bufferDart);
      nwritten += sftp_write(
          remoteFile, bufferNative.cast(), sizeOf<Int8>() * bufferSize);
    }
    await lfile.close();
    allocator.free(bufferNative);
    allocator.free(remoteFile);
    // print('localFileLength: $localFileLength | nwritten: $nwritten');
    //print('localFile:  ${utf8.decode(builder.takeBytes())}');

    if (nwritten < localFileLength) {
      sftp_close(remoteFile);
      sftp_free(sftp);
      throw Exception(
          'Can\'t write data to file, incomplete file: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }

    var rc = sftp_close(remoteFile);
    if (rc != SSH_OK) {
      sftp_free(sftp);
      throw Exception(
          'Can\'t close the written file: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }

    sftp_close(remoteFile);
    sftp_free(sftp);
  }

  Future<void> sftpDownloadFileToFromRawPath(
      ssh_session session, Uint8List fullRemotePath, String fullLocalPath,
      {void Function(int total, int done)? callbackStats,
      Pointer<sftp_session_struct>? inSftp,
      Allocator allocator = calloc}) async {
    var ftpfile = uint8ListToPointerInt8(fullRemotePath, allocator: allocator);
    await sftpDownloadFileTo(session, ftpfile, fullLocalPath,
        inSftp: inSftp, allocator: allocator);
    allocator.free(ftpfile);
  }

//
  Future<void> sftpDownloadFileTo(
      ssh_session session, Pointer<Int8> ftpfile, String fullLocalPath,
      {void Function(int total, int done)? callbackStats,
      Pointer<sftp_session_struct>? inSftp,
      Allocator allocator = calloc,
      bool recursive = true}) async {
    var sftp = inSftp != null ? inSftp : initSftp(session);

    //int res = 0;
    int totalReceived = 0;
    int totalSize = -1;
    int retcode = 0;
    var bufsize = 128 * 1024; //MAX_XFER_BUF_SIZE = 16384 = 16KB
    //Pointer<Uint32> len = nullptr; //lpNumberOfBytesWritten

    var sfile = sftp_open(sftp, ftpfile, O_RDONLY, 0664);
    if (sfile.address == nullptr.address) {
      sftp_free(sftp);
      throw Exception(
          'Can\'t open file for reading: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }

    var fattr = sftp_stat(sftp, ftpfile);
    if (fattr.address == nullptr.address) {
      totalSize = -1;
    } else {
      totalSize = fattr.ref.size;
      sftp_attributes_free(fattr);
    }

    /*var hFile = CreateFile(
        fullLocalPath.toNativeUtf16(), // name of the write
        GENERIC_READ | GENERIC_WRITE, // open for writing
        0, // do not share
        nullptr, // default security
        CREATE_ALWAYS, // create new file only
        FILE_ATTRIBUTE_NORMAL, // normal file
        0);
    if (hFile == INVALID_HANDLE_VALUE) {
      throw Exception('Unable to open local file $ftpfile for write.');
    }*/

    var localFile = File(fullLocalPath);
    var hFile = localFile.openSync(mode: FileMode.write);

    final buf = allocator<Int8>(bufsize);
    do {
      retcode = sftp_read(sfile, buf.cast<Void>(), bufsize);

      /*res = WriteFile(hFile, buf, retcode, len, nullptr);
      if (res == FALSE) {
        print("Terminal failure: Unable to write to file.\n");
        break;
      }*/
      totalReceived += retcode;
      if (callbackStats != null) {
        callbackStats(totalSize, totalReceived);
      }

      //print('retcode: $retcode data: ${data.length}');
      hFile.writeFromSync(buf.asTypedList(retcode));
      //retcode = sftp_read(sfile, buf.cast<Void>(), bufsize);

    } while (retcode > 0);
    //await hFile.flush();
    await hFile.close();

    var localFileLength = localFile.lengthSync();
    if (localFileLength < totalReceived) {
      sftp_close(sfile);
      if (inSftp == null) {
        sftp_free(sftp);
      }
      allocator.free(buf);
      throw Exception(
          'Incomplete file: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }

    var rc = sftp_close(sfile);
    if (rc != SSH_OK) {
      if (inSftp == null) {
        sftp_free(sftp);
      }
      allocator.free(buf);
      throw Exception(
          'Can\'t close the written file: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }

    if (inSftp == null) {
      sftp_free(sftp);
    }
    allocator.free(ftpfile);
    allocator.free(buf);
  }
}
