//import 'dart:ffi' as ffi;

/*
class stat extends ffi.Struct {
  @ffi.Int32()
  external int st_dev;

  @ffi.Int32()
  external int st_ino;

  @ffi.Int32()
  external int st_mode;

  @ffi.Int32()
  external int st_nlink;

  @ffi.Int32()
  external int st_uid;

  @ffi.Int32()
  external int st_gid;

  @ffi.Int32()
  external int st_rdev;

  @ffi.Int32()
  external int st_size;

  @ffi.Int32()
  external int st_atime;

  @ffi.Int64()
  external int st_spare1;

  @ffi.Int32()
  external int st_mtime;

  @ffi.Int64()
  external int st_spare2;

  @ffi.Int32()
  external int st_ctime;

  @ffi.Int64()
  external int st_spare3;

  @ffi.Int64()
  external int st_blksize;

  @ffi.Int64()
  external int st_blocks;

  @ffi.Int32()
  external int st_flags;

  @ffi.Int32()
  external int st_gen;
}
*/
const int S_ISGID = 1024;

const int S_ISTXT = 512;

///read, write, execute/search by owner 0000700	 RWX mask for owner */
const int S_IRWXU = 448;

const int S_IRUSR = 256;

const int S_IWUSR = 128;

const int S_IXUSR = 64;

const int S_IREAD = 256;

const int S_IWRITE = 128;

const int S_IEXEC = 64;

const int S_IRWXG = 56;

const int S_IRGRP = 32;

const int S_IWGRP = 16;

const int S_IXGRP = 8;

const int S_IRWXO = 7;

const int S_IROTH = 4;

const int S_IWOTH = 2;

const int S_IXOTH = 1;

const int S_IFMT = 61440;

const int S_IFIFO = 4096;

const int S_IFCHR = 8192;

const int S_IFDIR = 16384;

const int S_IFBLK = 24576;

const int S_IFREG = 32768;

const int S_IFLNK = 40960;

const int S_IFSOCK = 49152;

const int S_ISVTX = 512;

const int S_BLKSIZE = 512;

const int DEFFILEMODE = 438;
