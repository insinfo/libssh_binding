import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:libssh_binding/src/constants.dart';
import 'package:libssh_binding/src/exceptions/libssh_cancel_exception.dart';
import 'package:libssh_binding/src/exceptions/libssh_get_file_size_exception.dart';
import 'package:libssh_binding/src/exceptions/libssh_incomplete_file_exception.dart';
import 'package:libssh_binding/src/exceptions/libssh_memory_allocation_exception.dart';
import 'package:libssh_binding/src/exceptions/libssh_receiving_file_data_exception.dart';
import 'package:libssh_binding/src/exceptions/libssh_receiving_file_information_exception.dart';
import 'package:libssh_binding/src/exceptions/libssh_scp_accept_request_exception.dart';
import 'package:libssh_binding/src/extensions/exec_command_extension.dart';
import 'package:libssh_binding/src/libssh_binding.dart';
import 'package:libssh_binding/src/utils.dart';

extension ScpExtension on LibsshBinding {
  /// [fullPath] example => "helloworld/helloworld.txt"
  String scpReadFileAsString(ssh_session session, String fullPath, {Allocator allocator = calloc}) {
    var path = fullPath.toNativeUtf8(allocator: allocator);
    var scp = ssh_scp_new(session, SSH_SCP_READ, path.cast<Int8>());
    if (scp.address == nullptr.address) {
      throw Exception('Error allocating scp session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    var rc = ssh_scp_init(scp);
    if (rc != SSH_OK) {
      ssh_scp_free(scp);
      throw Exception("Error initializing scp session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}");
    }

    rc = ssh_scp_pull_request(scp);
    if (rc != ssh_scp_request_types.SSH_SCP_REQUEST_NEWFILE) {
      throw Exception(
          "Error receiving information about file: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}");
    }

    var remoteFileLength = ssh_scp_request_get_size64(scp);

    //var filename = ssh_scp_request_get_filename(scp).cast<Utf8>();
    //var mode = ssh_scp_request_get_permissions(scp);
    //var controller = StreamController<List<int>>();

    int bufferSize = MAX_XFER_BUF_SIZE; //remoteFileLength > bs ? bs : remoteFileLength;

    var nbytes = 0, nwritten = 0;
    final buffer = allocator<Int8>(bufferSize);
    var receive = '';

    while (true) {
      nbytes = ssh_scp_read(scp, buffer.cast(), sizeOf<Int8>() * bufferSize);
      nwritten += nbytes;

      var data = buffer.asTypedList(nbytes);
      receive += utf8.decode(data);

      if (nbytes < 0 || nbytes == SSH_ERROR) {
        ssh_scp_close(scp);
        ssh_scp_free(scp);
        allocator.free(buffer);
        break;
      }
    }
    allocator.free(path);
    if (nwritten < remoteFileLength) {
      throw Exception("Error Incomplete file");
    }
    return receive;
  }

  Pointer<ssh_scp_struct> initFileScp(ssh_session session, Pointer<Int8> remoteFilePath) {
    var scp = ssh_scp_new(session, SSH_SCP_READ, remoteFilePath);
    if (scp.address == nullptr.address) {
      throw Exception(
          'Error allocating scp file session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    var rc = ssh_scp_init(scp);
    if (rc != SSH_OK) {
      ssh_scp_free(scp);
      throw Exception(
          "Error initializing scp file session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}");
    }
    return scp;
  }

  Pointer<ssh_scp_struct> initDirectoryScp(ssh_session session, Pointer<Int8> remoteDirectoryPath) {
    var scp = ssh_scp_new(session, SSH_SCP_READ | SSH_SCP_RECURSIVE, remoteDirectoryPath);
    if (scp == nullptr) {
      throw Exception(
          'Error allocating scp directory session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    var rc = ssh_scp_init(scp);
    if (rc != SSH_OK) {
      ssh_scp_free(scp);
      throw Exception(
          "Error initializing scp directory session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}");
    }
    return scp;
  }

  Future<void> scpDownloadFileTo(
    ssh_session session,
    String fullRemotePathSource,
    String fullLocalPathTarget, {
    void Function(int totalBytes, int loaded)? callbackStats,
    Allocator allocator = calloc,
    bool recursive = true,
    bool Function()? cancelCallback,
    bool dontStopIfFileException = false,
  }) async {
    var source = fullRemotePathSource.toNativeUtf8(allocator: allocator).cast<Int8>();

    var scp = initFileScp(session, source);
    var rc = ssh_scp_pull_request(scp);
    if (rc != ssh_scp_request_types.SSH_SCP_REQUEST_NEWFILE) {
      ssh_scp_free(scp);
      throw LibsshReceivingFileInformationException(
          "Error receiving information about file: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}");
    }

    rc = ssh_scp_accept_request(scp);
    if (rc == SSH_ERROR) {
      ssh_scp_close(scp);
      ssh_scp_free(scp);
      throw LibsshScpAcceptRequestException(
          "Error ssh_scp_accept_request: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}");
    }
    try {
      await scpReadFileAndSave(session, scp, Uint8List.fromList(fullLocalPathTarget.codeUnits),
          allocator: allocator,
          callbackStats: callbackStats,
          recursive: recursive,
          cancelCallback: cancelCallback,
          dontStopIfFileException: dontStopIfFileException);
    } catch (e) {
      rethrow;
    } finally {
      allocator.free(source);
      ssh_scp_close(scp);
      ssh_scp_free(scp);
    }
  }
  //compress folder tar -zcvf backup-teste.tar.gz /var/run
  //copy all files from a directory to a remote directory using scp?
  //scp -r ~/local_dir user@host.com:/var/www/html/target_dir
  //scp -r /var/www/html/portal2018/wp-content/themes/pmro/educacao isaque.neves@192.168.133.13:/var/www/html/educacao
  //nano /etc/nginx/sites-enabled/default
  // find ./ -type f -print0 | xargs -0 stat --format=%s | awk '{s+=$1} END {print s}'

  ///return total size in bytes of each file inside folder ignoring linux directory metadata size
  int getSizeOfDirectory(Pointer<ssh_session_struct> session, String remoteDirectoryPath,
      {bool isThrowException = true}) {
    //windows = 1041090242
    //debian < 6 : find /var/www -type f -print0 | xargs -0 stat --format=%s |  paste -sd+ - | bc -l
    //ls -lAR | grep -v '^d' | awk '{total += $5} END {print "Total:", total}'
    //linux = 1041090469 -> find ./dart/  -type f -print | xargs -d '\n' du -bs | awk '{ sum+=$1} END {print sum}'
    var cmdToGetTotaSize =
        "find $remoteDirectoryPath -type f -print0 | xargs -0 stat --format=%s | awk '{s+=\$1} END {print s}'";
    String? cmdRes;
    try {
      cmdRes = execCommandSync(session, cmdToGetTotaSize);
      if (cmdRes.trim().isEmpty) {
        //verifica se é um link sinbolico file /var/run
        //var/run: symbolic link to /run
        cmdRes = execCommandSync(session, 'file $remoteDirectoryPath');
        //é um link sinbolico ?
        if (cmdRes.contains('symbolic')) {
          //obtem o caminho real do link sinbolico
          var cmdRe = execCommandSync(session, 'readlink -f $remoteDirectoryPath');
          if (cmdRe.trim().isNotEmpty) {
            cmdRes = execCommandSync(session,
                "find ${cmdRe.replaceAll(RegExp(r'\n'), '')} -type f -print0 | xargs -0 stat --format=%s | awk '{s+=\$1} END {print s}'");
          }
        }
      }
      //para debian antigos como debian 6
      //exeplo 1.57903e+10
      if (cmdRes.contains('e+')) {
        cmdRes = execCommandSync(
            session, 'find $remoteDirectoryPath -type f -print0 | xargs -0 stat --format=%s |  paste -sd+ - | bc -l');
      } else if (int.tryParse(cmdRes) == null) {
        //du -s -B1 /var/www
        //4096 * 23775 = 97382400
        //obter total de diretorios => find /var/www  -type d -print| wc -l
        // find /var/www -type f -print0 | du -scb -L --apparent-size --files0-from=- | tail -n 1
        //cmdRes = execCommandSync(session, 'du -sb --apparent-size --block-size=1 $remoteDirectoryPath');
        cmdRes = execCommandSync(session,
            'find $remoteDirectoryPath -type f -print0 | du -scb -L --apparent-size --files0-from=- | tail -n 1');
        return int.parse(cmdRes.split(' ').first.trim());
      }

      return int.parse(cmdRes);
    } catch (e) {
      print('getSizeOfDirectory: $e \r\n cmdToGetTotaSize: $cmdToGetTotaSize \r\n cmdRes: $cmdRes');
      if (isThrowException) {
        throw LibsshGetFileSizeException(
            'Unable to get the size of a directory in bytes, \r\n cmd: $cmdToGetTotaSize cmdResult: $cmdRes');
      }
    }
    return 0;
  }

  ///return total size in bytes of file , work on  GNU/Linux systems, tested in debian 10
  ///based on https://unix.stackexchange.com/questions/16640/how-can-i-get-the-size-of-a-file-in-a-bash-script/185039#185039
  int getSizeOfFile(Pointer<ssh_session_struct> session, String remoteFilePath, {bool isThrowException = true}) {
    //stat --format="%s" /var/www/html/'JUNHO 2021 - Controle de Dias Trabalhados.xlsx'
    try {
      var cmdToGetTotaSize = 'stat --format="%s" $remoteFilePath ';
      var cmdRes = execCommandSync(session, cmdToGetTotaSize);
      return int.parse(cmdRes);
    } catch (e) {
      print('getSizeOfFile: $e');
      if (isThrowException) {
        throw LibsshGetFileSizeException('Unable to get the size of a file in bytes');
      }
    }
    return 0;
  }

  Future<void> scpReadFileAndSave(
    Pointer<ssh_session_struct> session,
    Pointer<ssh_scp_struct> scp,
    Uint8List fullLocalPathTarget, {
    void Function(int totalBytes, int loaded)? callbackStats,
    Allocator allocator = calloc,
    bool recursive = false,
    bool Function()? cancelCallback,
    bool dontStopIfFileException = false,
    void Function(Object? obj)? printLog,
    int bufferSize = 128 * 1024,
  }) async {
    var remoteFileLength = ssh_scp_request_get_size(scp);
    //var filename = ssh_scp_request_get_filename(scp).cast<Utf8>();
    //var permissions = ssh_scp_request_get_permissions(scp);
    //intToPermissionString(permissions);
    RandomAccessFile? hFile;
    Pointer<Int8>? buffer;
    //function used to print log info
    var printFunc = printLog != null ? printLog : print;
    try {
      var targetFile = await File.fromRawPath(fullLocalPathTarget).create(recursive: recursive);
      hFile = targetFile.openSync(mode: FileMode.write); // for appending at the end of file
      int lenLoop = remoteFileLength;
      var nbytes = 0, nwritten = 0;
      //MAX_XFER_BUF_SIZE = 16384 = 16KB
      buffer = allocator<Int8>(bufferSize);
      if (buffer.address == nullptr.address) {
        throw LibsshMemoryAllocationException();
      }
      var bfs = sizeOf<Int8>() * bufferSize;
      do {
        nbytes = ssh_scp_read(scp, buffer.cast(), bfs);
        nwritten += nbytes;
        if (callbackStats != null) {
          callbackStats(remoteFileLength, nwritten);
        }
        if (cancelCallback != null) {
          if (cancelCallback()) {
            throw LibsshCancelException();
          }
        }
        if (nbytes == SSH_ERROR || nbytes < 0) {
          throw LibsshReceivingFileDataException(
              'Error receiving file data: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
        } else if (nbytes == 0) {
          break;
        }
        //print('nbytes $nbytes nwritten $nwritten');
        hFile.writeFromSync(buffer.asTypedList(nbytes));
        lenLoop -= nbytes;
      } while (lenLoop != 0);

      var localFileLength = targetFile.lengthSync();
      if (localFileLength < nwritten) {
        throw LibsshIncompleteFileException("Error Incomplete file: ${targetFile.path}");
      }
    } on FileSystemException catch (e) {
      if (dontStopIfFileException) {
        printFunc('scpReadFileAndSave: $e');
      } else {
        rethrow;
      }
    } catch (e) {
      rethrow;
    } finally {
      await hFile?.close();
      if (buffer != null) {
        allocator.free(buffer);
      }
    }
  }

  /// [fullLocalDirectoryPathTarget] example c:\downloads
  /// this function work only if remote is linux debian like sytem
  /// [callbackStats] function to show stattistcs callbackStats(totalSize, loaded, countDirectory, countFiles)
  /// [printLog] callback for print log messagens
  /// [updateStatsOnFileEnd] if true call callbackStats on file download end , if false call callbackStats on directory end
  Future<dynamic>? scpDownloadDirectory(
    Pointer<ssh_session_struct> session,
    String remoteDirectoryPath,
    String fullLocalDirectoryPathTarget, {
    Allocator allocator = calloc,
    void Function(
      int totalBytes,
      int loaded,
      int currentFileSize,
      int countDirectory,
      int countFiles,
    )?
        callbackStats,
    void Function(Object? obj)? printLog,
    bool updateStatsOnFileEnd = true,
    bool isThrowException = false,
    bool Function()? cancelCallback,
    bool dontStopIfFileException = false,
  }) async {
    var source = remoteDirectoryPath.toNativeUtf8(allocator: allocator).cast<Int8>();
    //function used to print log info
    var printFunc = printLog != null ? printLog : print;

    var currentPath = '${fullLocalDirectoryPathTarget.replaceAll('\\', '/')}';

    int totalSize = 0, loaded = 0, countDirectory = 0, countFiles = 0;
    int currentFileSize = 0;
    var currentDirName = '';

    totalSize = getSizeOfDirectory(session, remoteDirectoryPath, isThrowException: isThrowException);
    printFunc(
        'scpDownloadDirectory: total size: $totalSize in bytes | ${totalSize > 0 ? totalSize / 1024 / 1024 : totalSize} megabytes of directory $remoteDirectoryPath');
    var scp = initDirectoryScp(session, source);

    var rc = 0;

    bool exitLoop = false;
    do {
      rc = ssh_scp_pull_request(scp);
      if (exitLoop) {
        break;
      }

      if (cancelCallback != null) {
        if (cancelCallback()) {
          allocator.free(source);
          ssh_scp_close(scp);
          ssh_scp_free(scp);
          throw LibsshCancelException();
        }
      }

      switch (rc) {
        //Um novo arquivo será obtido
        case ssh_scp_request_types.SSH_SCP_REQUEST_NEWFILE:
          var rawFilename = nativeInt8ToCodeUnits(ssh_scp_request_get_filename(scp));

          var tempFilename = uint8ListToString(rawFilename);

          ///TODO checar arquivos com o caracter �
          if (isInvalidFilename(tempFilename)) {
            var newFilename = sanitizeFilename(tempFilename);
            printFunc('invalid filename:  $currentPath/$tempFilename \r\n renamed to:  $newFilename');
            rawFilename = Uint8List.fromList(newFilename.codeUnits);
          }

          currentFileSize = ssh_scp_request_get_size64(scp);
          //concatena o caminho atual com o nome do arquivo
          //'$currentPath/$filename'
          var fullLocalPathTarget = concatUint8List(
              [Uint8List.fromList(currentPath.codeUnits), Uint8List.fromList('/'.codeUnits), rawFilename]);

          ssh_scp_accept_request(scp);

          await scpReadFileAndSave(
            session,
            scp,
            fullLocalPathTarget,
            recursive: true,
            allocator: allocator,
            cancelCallback: cancelCallback,
            dontStopIfFileException: dontStopIfFileException,
            printLog: printFunc,
          );

          countFiles++;
          loaded += currentFileSize;

          if (callbackStats != null && updateStatsOnFileEnd == true) {
            //(int total, int loaded, int countDirectory, int countFiles)
            callbackStats(totalSize, loaded, currentFileSize, countDirectory, countFiles);
          }
          break;
        case SSH_ERROR:
          if (isThrowException) {
            allocator.free(source);
            ssh_scp_close(scp);
            ssh_scp_free(scp);
            throw Exception(
                'scpDownloadDirectory: SSH_ERROR: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
          }
          printFunc('scpDownloadDirectory: SSH_ERROR: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
          exitLoop = true;
          break;
        case ssh_scp_request_types.SSH_SCP_REQUEST_WARNING:
          printFunc('scpDownloadDirectory: Warning: ${ssh_scp_request_get_warning(scp).cast<Utf8>().toDartString()}');
          break;
        //Um novo diretório será puxado
        case ssh_scp_request_types.SSH_SCP_REQUEST_NEWDIR:
          currentDirName = nativeInt8ToString(ssh_scp_request_get_filename(scp), allowMalformed: true);

          if (isInvalidFilename(currentDirName)) {
            var newDirname = sanitizeFilename(currentDirName);
            var p = '$currentPath/$currentDirName';
            printFunc('invalid directory name:  $p \r\n renamed to:  $newDirname');
            currentDirName = newDirname;
          }

          //currentDirSize = ssh_scp_request_get_size64(scp);
          //var mode = ssh_scp_request_get_permissions(scp);
          currentPath += '/$currentDirName';
          /*if (isFirstDirectory == true) {
            rootDirName = '/$currentDirName';
            isFirstDirectory = false;
          }*/
          Directory('$currentPath').createSync(recursive: true);
          countDirectory++;
          //print("directory: $currentDirName | currentPath: $currentPath");
          if (callbackStats != null && updateStatsOnFileEnd == false) {
            //(int total, int loaded, int countDirectory, int countFiles)
            callbackStats(totalSize, loaded, currentFileSize, countDirectory, countFiles);
          }
          ssh_scp_accept_request(scp);
          break;
        //End of directory
        case ssh_scp_request_types.SSH_SCP_REQUEST_ENDDIR:
          var parts = currentPath.split('/');
          parts.removeLast();
          currentPath = parts.join('/');
          //print("End of directory ");
          break;
        case ssh_scp_request_types.SSH_SCP_REQUEST_EOF:
          printFunc("scpDownloadDirectory: end of directories");
          exitLoop = true;
          break;
        default:
          break;
      }
    } while (true);
    printFunc('scpDownloadDirectory: total size: $totalSize | copied: $loaded ');
    allocator.free(source);
    ssh_scp_close(scp);
    ssh_scp_free(scp);
    return null;
  }
}
