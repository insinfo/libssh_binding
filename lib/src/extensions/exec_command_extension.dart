import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libssh_binding/src/libssh_binding.dart';

extension ExecSshCommandExtension on LibsshBinding {
  ssh_channel initSshChannel(ssh_session session) {
    ssh_channel channel = ssh_channel_new(session);
    if (channel.address == nullptr.address) {
      throw Exception(
          'Error allocating ssh_channel session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }

    var rc = ssh_channel_open_session(channel);
    if (rc != SSH_OK) {
      ssh_channel_free(channel);
      throw Exception(
          'Error on ssh_channel_open_session: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    return channel;
  }

  void disposeSshChannel(ssh_channel channel) {
    ssh_channel_send_eof(channel);
    ssh_channel_close(channel);
    ssh_channel_free(channel);
  }

  /// execute only one command
  /// to execute several commands
  /// start a scripting language
  /// example:
  /// execCommandSync(session,"cd /tmp; mkdir mytest; cd mytest; touch mytest");
  String execCommandSync(ssh_session session, String command,
      {Allocator allocator = calloc, bool returnStderr = false}) {
    var receive = "";
    final channel = initSshChannel(session);
    try {
      receive = execCommandOnChannel(session, channel, command, allocator: allocator, returnStderr: returnStderr);
    } catch (e) {
      rethrow;
    } finally {
      disposeSshChannel(channel);
    }
    return receive;
  }

  /// experimental as it may not be able to detect the prompt
  /// execute commands in the interactive shell the order of execution is based on the order of the command list
  /// and return a list with the response of each command in the order of execution
  List<String> execCommandsInShell(ssh_session session, List<String> commands) {
    var channel = initSshChannel(session);
    var results = <String>[];
    initShell(session, channel);
    //read shell header and discard
    channelReadAsString(session, channel, isPty: true);
    //executa os comandos
    for (var cmd in commands) {
      channelWrite(session, channel, "echo ----STARTCMD----; $cmd; echo ----ENDCMD---- \r");
      var resp = channelReadAsString(session, channel, isPty: true);
      //remove ----STARTCMD---- and ----ENDCMD---- of result
      resp = resp.substring(resp.lastIndexOf('----STARTCMD----') + 18);
      resp = resp.substring(0, resp.lastIndexOf('----ENDCMD----'));
      //remove fist and last line
      var rgeline = RegExp("[\n\r]"); //'\n|\r|\r\n'
      if (resp.indexOf(rgeline) != -1) {
        resp = resp.substring(0, resp.lastIndexOf(rgeline));
      }
      /*
      if (removeFistAndLastLine) {        
        var lines = results.split(rgeline);
        var lastLine = lines.last.trim();
        results = results.replaceAll(lines.first.trim(), '');
        results = results.replaceAll(lastLine.trim(), '');
      }*/

      results.add(resp);
    }

    disposeSshChannel(channel);
    return results;
  }

  String execCommandOnChannel(ssh_session session, Pointer<ssh_channel_struct> channel, String command,
      {Allocator allocator = calloc, bool returnStderr = false}) {
    var cmd = command.toNativeUtf8().cast<Int8>();
    var rc = ssh_channel_request_exec(channel, cmd);
    if (rc != SSH_OK) {
      allocator.free(cmd);
      throw Exception(
          'Error on ssh_channel_request_exec: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    var receive = '';
    receive = channelReadAsString(session, channel, allocator: allocator, isStderr: false);
    if (returnStderr) {
      receive += channelReadAsString(session, channel, allocator: allocator, isStderr: true);
    }
    allocator.free(cmd);
    return receive;
  }

  void initShell(ssh_session session, Pointer<ssh_channel_struct> channel) {
    int rc = 0;
    rc = ssh_channel_request_pty(channel);
    //rc = ssh_channel_change_pty_size(channel, 80, 24);
    rc = ssh_channel_request_shell(channel);
    if (rc != SSH_OK) {
      throw Exception(
          'Error on ssh_channel_request_shell: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
  }

  void channelWrite(ssh_session session, Pointer<ssh_channel_struct> channel, String command,
      {Allocator allocator = calloc}) {
    final units = utf8.encode(command);
    int size = units.length + 1;
    final Pointer<Uint8> result = allocator<Uint8>(size);
    final Uint8List nativeString = result.asTypedList(size);
    nativeString.setAll(0, units);
    nativeString[units.length] = 0;
    var rc = ssh_channel_write(channel, result.cast(), size);
    //print('channelWrite rc: $rc size: ${size} ${command.length}');
    if (rc == SSH_ERROR) {
      throw Exception('Error on ssh_channel_write: ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
    }
    //allocator.free(result);
  }

  /// [timeout] in Milliseconds para interromper o loop
  /// [isCustomPty] verifica se existe um "----ENDCMD----" na string retornada pelo server e interronpe o loop
  /// [isPty] verifica se existe um "#" or "$" prompts na string retornada pelo server e interronpe o loop
  String channelReadAsString(ssh_session session, Pointer<ssh_channel_struct> channel,
      {int? limitLoop,
      Allocator allocator = calloc,
      bool isStderr = false,
      bool isPty = false,
      int? timeout,
      bool isCustomPty = false}) {
    var bufSize = 256;
    final buffer = allocator<Int8>(bufSize); //	char buffer[256];
    int nbytes = 0;
    var receive = "";
    int count = 0;

    var stopwatch = Stopwatch()..start();
    while ((ssh_channel_is_open(channel) != 0) && !(ssh_channel_is_eof(channel) != 0)) {
      nbytes = ssh_channel_read(channel, buffer.cast(), sizeOf<Int8>() * bufSize, isStderr == true ? 1 : 0);
      if (count == limitLoop) {
        break;
      }
      if (nbytes < 0) {
        stopwatch.stop();
        allocator.free(buffer);
        throw Exception('Error on ssh_channel_read ${ssh_get_error(session.cast()).cast<Utf8>().toDartString()}');
      }
      if (nbytes == 0) {
        break;
      }
      if (nbytes > 0) {
        receive += utf8.decode(buffer.asTypedList(nbytes));
      }

      if (timeout != null) {
        if (stopwatch.elapsed.inMilliseconds > timeout) {
          stopwatch.stop();
          allocator.free(buffer);
          throw Exception('The ssh_channel_read timeout of $timeout exceeded');
        }
      }

      if (isPty) {
        //detect shell prompt
        try {
          var rgx = RegExp(r'(\$|%|#|>|$ )');
          var lines = receive.split(RegExp('\n|\r|\r\n'));
          var lastLine = lines.last.trim();
          if (lastLine.contains(rgx)) {
            break;
          }
        } catch (e) {
          stopwatch.stop();
          allocator.free(buffer);
          throw Exception('failed to detect shell prompt');
        }
      }
      if (isCustomPty) {
        if (receive.contains('----ENDCMD----')) {
          break;
        }
      }
      count++;
    }
    stopwatch.stop();
    allocator.free(buffer);
    return receive;
  }
}

/*extension StringUtf8Pointer on String {
  
  Pointer<Utf8> toNativeUtf8({Allocator allocator = calloc}) {
    final units = utf8.encode(this);
    final Pointer<Uint8> result = allocator<Uint8>(units.length + 1);
    final Uint8List nativeString = result.asTypedList(units.length + 1);
    nativeString.setAll(0, units);
    nativeString[units.length] = 0;
    return result.cast();
  }
}*/
