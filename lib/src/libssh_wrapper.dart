import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:libssh_binding/src/extensions/exec_command_extension.dart';
import 'package:libssh_binding/src/extensions/scp_extension.dart';
import 'package:libssh_binding/src/extensions/sftp_extension.dart';
import 'package:libssh_binding/src/models/directory_item.dart';
import 'package:libssh_binding/src/utils.dart';
import 'package:path/path.dart' as path;
import 'package:ffi/ffi.dart';
import 'package:libssh_binding/src/libssh_binding.dart';
import 'package:libssh_binding/src/sftp_binding.dart';

class LibssOptions {
  late String host;
  String? username;
  String? password;
  int port = 22;
  bool verbosity = false;
  DynamicLibrary? inDll;
  String ddlname = 'ssh.dll';
  bool defaultDllPath = true;

  LibssOptions(this.host,
      {this.username,
      this.password,
      this.port = 22,
      this.verbosity = false,
      this.ddlname = 'ssh.dll',
      this.inDll,
      this.defaultDllPath = true});
}

/// high-level wrapper on top of libssh binding - The SSH library!
/// libssh is a multiplatform C library implementing the SSHv2 protocol on client and server side.
/// With libssh, you can remotely execute programs, transfer files, use a secure and transparent tunnel
/// https://www.libssh.org/
class LibsshWrapper {
  late ssh_session mySshSession;
  late LibsshBinding libsshBinding;
  late String host;
  String? username;
  String? password;
  int port = 22;
  bool isConnected = false;
  bool verbosity = false;

  /// if defaultDllPath == true get ddl from default sytem folder Exemple: in windows c:\windows\Sytem32
  /// else get dll from Directory.current.path
  LibsshWrapper(this.host,
      {this.username,
      this.password,
      this.port = 22,
      bool defaultDllPath = true,
      DynamicLibrary? inDll,
      String ddlname = 'ssh.dll',
      this.verbosity = false}) {
    var libraryPath = defaultDllPath
        ? ddlname
        : path.join(Directory.current.path, ddlname); //'libssh_compiled',
    final dll = inDll == null ? DynamicLibrary.open(libraryPath) : inDll;
    libsshBinding = LibsshBinding(dll);
    mySshSession = initSsh();
  }

  LibsshWrapper.fromOptions(LibssOptions options) {
    var libraryPath = options.defaultDllPath
        ? options.ddlname
        : path.join(
            Directory.current.path, options.ddlname); //'libssh_compiled',
    host = options.host;
    username = options.username;
    password = options.password;
    port = options.port;
    verbosity = options.verbosity;

    final dll = options.inDll == null
        ? DynamicLibrary.open(libraryPath)
        : options.inDll;
    libsshBinding = LibsshBinding(dll!);
    mySshSession = initSsh();
  }

  /// initialize ssh - Open the session and set the options
  ssh_session initSsh() {
    // Open the session and set the options
    var mySession = libsshBinding.ssh_new();
    libsshBinding.ssh_options_set(
        mySession, ssh_options_e.SSH_OPTIONS_HOST, stringToNativeVoid(host));
    libsshBinding.ssh_options_set(
        mySession, ssh_options_e.SSH_OPTIONS_PORT, intToNativeVoid(port));
    if (verbosity == true) {
      libsshBinding.ssh_options_set(
          mySession,
          ssh_options_e.SSH_OPTIONS_LOG_VERBOSITY,
          intToNativeVoid(SSH_LOG_PROTOCOL));
    }
    libsshBinding.ssh_options_set(mySession, ssh_options_e.SSH_OPTIONS_USER,
        stringToNativeVoid(username!));
    return mySession;
  }

  /// Connect to SSH server
  void connect() {
    var rc = libsshBinding.ssh_connect(mySshSession);
    if (rc != SSH_OK) {
      isConnected = false;
      throw Exception('Error connecting to host: $host \n');
    }
    rc = libsshBinding.ssh_userauth_password(mySshSession,
        stringToNativeInt8(username!), stringToNativeInt8(password!));
    if (rc != ssh_auth_e.SSH_AUTH_SUCCESS) {
      isConnected = false;
      throw Exception(
          "Error authenticating with password: ${libsshBinding.ssh_get_error(mySshSession.cast()).cast<Utf8>().toDartString()}\n");
    }
    isConnected = true;
  }

  /// check if session started and connection is open
  void isReady() {
    if (mySshSession == nullptr) {
      throw Exception('SSH session is not initialized');
    }
    if (isConnected == false) {
      throw Exception('SSH is not connected');
    }
  }

  /// downloads a file from an SFTP/SCP server
  Future<void> scpDownloadFileTo(
    String fullRemotePathSource,
    String fullLocalPathTarget, {
    void Function(int, int)? callbackStats,
    bool recursive = true,
    bool Function()? cancelCallback,
    bool dontStopIfFileException = false,
  }) async {
    isReady();

    await libsshBinding.scpDownloadFileTo(
      mySshSession,
      fullRemotePathSource,
      fullLocalPathTarget,
      callbackStats: callbackStats,
      recursive: recursive,
      cancelCallback: cancelCallback,
      dontStopIfFileException: dontStopIfFileException,
    );
  }

  /// download one file via SFTP of remote server
  Future<void> sftpDownloadFileTo(String fullRemotePath, String fullLocalPath,
      {Pointer<sftp_session_struct>? inSftp,
      Allocator allocator = calloc,
      bool recursive = true}) async {
    isReady();
    var ftpfile =
        fullRemotePath.toNativeUtf8(allocator: allocator).cast<Int8>();
    await libsshBinding.sftpDownloadFileTo(mySshSession, ftpfile, fullLocalPath,
        inSftp: inSftp, allocator: allocator);
  }

  Future<void> sftpDownloadFileToFromRawPath(
      Uint8List fullRemotePath, String fullLocalPath,
      {Pointer<sftp_session_struct>? inSftp,
      Allocator allocator = calloc}) async {
    isReady();

    await libsshBinding.sftpDownloadFileToFromRawPath(
        mySshSession, fullRemotePath, fullLocalPath,
        inSftp: inSftp, allocator: allocator);
  }

  /// execute only one command
  /// to execute several commands
  /// start a scripting language
  /// example:
  /// execCommandSync(session,"cd /tmp; mkdir mytest; cd mytest; touch mytest");
  String execCommandSync(
    String command, {
    Allocator allocator = calloc,
  }) {
    isReady();
    return libsshBinding.execCommandSync(mySshSession, command,
        allocator: allocator);
  }

  /// experimental as it may not be able to detect the prompt
  /// execute commands in the interactive shell the order of execution is based on the order of the command list
  /// and return a list with the response of each command in the order of execution
  List<String> execCommandsInShell(List<String> commands) {
    return libsshBinding.execCommandsInShell(mySshSession, commands);
  }

  /// Listing the contents of a directory
  /// [fullRemotePath] one String fullRemotePath
  /// [allowMalformed] allow Malformed utf8 file and directory name
  List<DirectoryItem> sftpListDir(String fullRemotePath,
      {Allocator allocator = calloc, bool allowMalformed = false}) {
    return libsshBinding.sftpListDir(mySshSession, fullRemotePath,
        allowMalformed: allowMalformed);
  }

  /// Listing the contents of a directory
  /// [fullRemotePath] one Uint8List fullRemotePath
  /// [allowMalformed] allow Malformed utf8 file and directory name
  List<DirectoryItem> sftpListDirFromRawPath(List<int> fullRemotePath,
      {Allocator allocator = calloc, bool allowMalformed = false}) {
    return libsshBinding.sftpListDirFromRawPath(
        mySshSession, Uint8List.fromList(fullRemotePath),
        allowMalformed: allowMalformed);
  }

  ///return total size in bytes of each file inside folder ignoring linux directory metadata size
  int getSizeOfDirectory(String remoteDirectoryPath,
      {bool isThrowException = true}) {
    return libsshBinding.getSizeOfDirectory(mySshSession, remoteDirectoryPath,
        isThrowException: isThrowException);
  }

  ///return total size in bytes of file or directory , work on  GNU/Linux systems, tested in debian 10
  int getSizeOfFileSystemItem(DirectoryItem item,
      {bool isThrowException = true}) {
    if (item.type == DirectoryItemType.directory) {
      return getSizeOfDirectory(item.path, isThrowException: isThrowException);
    } else {
      return getSizeOfFile(item.path, isThrowException: isThrowException);
    }
  }

  ///return total size in bytes of file , work on  GNU/Linux systems, tested in debian 10
  ///based on https://unix.stackexchange.com/questions/16640/how-can-i-get-the-size-of-a-file-in-a-bash-script/185039#185039
  int getSizeOfFile(String remoteFilePath, {bool isThrowException = true}) {
    return libsshBinding.getSizeOfFile(mySshSession, remoteFilePath,
        isThrowException: isThrowException);
  }

  /// [fullLocalDirectoryPathTarget] example c:\downloads
  /// [remoteDirectoryPath] example /var/www
  /// this function work only if remote is linux debian like sytem
  Future<void> scpDownloadDirectory(
    String remoteDirectoryPath,
    String fullLocalDirectoryPathTarget, {
    Allocator allocator = calloc,
    void Function(int totalBytes, int loaded, int currentFileSize,
            int countDirectory, int countFiles)?
        callbackStats,
    void Function(Object? obj)? printLog,
    bool Function()? cancelCallback,
    bool isThrowException = false,
    bool updateStatsOnFileEnd = true,
    bool dontStopIfFileException = false,
  }) async {
    await libsshBinding.scpDownloadDirectory(
      mySshSession,
      remoteDirectoryPath,
      fullLocalDirectoryPathTarget,
      allocator: allocator,
      callbackStats: callbackStats,
      printLog: printLog,
      isThrowException: isThrowException,
      cancelCallback: cancelCallback,
      updateStatsOnFileEnd: updateStatsOnFileEnd,
      dontStopIfFileException: dontStopIfFileException,
    );
  }

  /// disconnect from server
  void disconnect() {
    libsshBinding.ssh_disconnect(mySshSession);
  }

  /// free memory
  void dispose() {
    disconnect();
    libsshBinding.ssh_free(mySshSession);
  }
}
