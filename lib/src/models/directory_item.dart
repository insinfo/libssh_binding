import 'dart:typed_data';

import 'package:libssh_binding/libssh_binding.dart';

/*

attr->type = SSH_FILEXFER_TYPE_SPECIAL;
          break;
        case SSH_S_IFLNK:
          attr->type = SSH_FILEXFER_TYPE_SYMLINK;
          break;
        case SSH_S_IFREG:
          attr->type = SSH_FILEXFER_TYPE_REGULAR;
          break;
        case SSH_S_IFDIR:
          attr->type = SSH_FILEXFER_TYPE_DIRECTORY;
          break;
        default:
          attr->type = SSH_FILEXFER_TYPE_UNKNOWN;
           */
enum DirectoryItemType { directory, file }

extension DirectoryItemTypeExtension on DirectoryItemType {
  String get text {
    return this.toString().split('.').last;
  }
}

class DirectoryItem {
  late String name;
  int? size;
  late DirectoryItemType type;
  late String path;
  String? longname;
  bool? isSymbolicLink = false;
  int? flags = 0;
  int? atime = 0;
  int? mtime = 0;
  int? createtime = 0;

  /// quando é link começã com L Ex: lrwxrwxrwx, quando é diretorio começa com d Ex: drwxr-xr-x
  int? permissions = 0;

  ///Uint8Lost of  fullRemotePath
  List<int>? nativePath;

  DirectoryItem({
    required this.name,
    this.size,
    required this.type,
    required this.path,
    this.longname,
    this.nativePath,
    this.isSymbolicLink = false,
    this.flags = 0,
    this.atime = 0,
    this.mtime = 0,
    this.createtime = 0,
    this.permissions = 0,
  });

  factory DirectoryItem.fromPath(String strPath) {
    var separator = strPath.contains('/') ? '/' : '\\';
    var name = strPath.split(separator).length > 2
        ? strPath.split(separator).last
        : strPath;

    var dir = DirectoryItem(
        name: name,
        path: strPath,
        nativePath: strPath.codeUnits,
        size: 0,
        type: DirectoryItemType.directory,
        isSymbolicLink: false);

    return dir;
  }

  String get nativePathAsString {
    if (nativePath != null) {
      return uint8ListToString(Uint8List.fromList(nativePath!));
    }
    return '';
  }

  void fillFromMap(Map<String, dynamic> map) {
    name = map['name'];
    path = map['path'];
    type = map['type'] == 'directory'
        ? DirectoryItemType.directory
        : DirectoryItemType.file;
    if (map.containsKey('nativePath') && map['nativePath'] is List) {
      nativePath = <int>[];
      (map['nativePath'] as List).forEach((element) {
        nativePath!.add(element as int);
      });
    }
    longname = map['longname'];
    size = map['size'];
    isSymbolicLink = map['isSymbolicLink'];
    flags = map['flags'];
    atime = map['atime'];
    mtime = map['mtime'];
    createtime = map['createtime'];
    permissions = map['permissions'];
  }

  factory DirectoryItem.fromMap(Map<String, dynamic> map) {
    final dir = DirectoryItem(name: '', path: '', type: DirectoryItemType.file);
    dir.fillFromMap(map);
    return dir;
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'name': name,
      'path': path,
      'type': type == DirectoryItemType.directory ? 'directory' : 'file',
    };
    if (nativePath != null) {
      map['nativePath'] = nativePath;
    }
    map['longname'] = longname;
    map['size'] = size;
    map['isSymbolicLink'] = isSymbolicLink;
    map['flags'] = flags;
    map['atime'] = atime;
    map['mtime'] = mtime;
    map['createtime'] = createtime;
    map['permissions'] = permissions;
    return map;
  }

  @override
  String toString() {
    return '$name';
  }
}
