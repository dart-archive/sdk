// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// File access APIs. Only supported when Dartino is running on a Posix platform.
///
/// Usage
/// -----
/// ```dart
/// import 'package:file/file.dart';
///
/// void main() {
///   var file = new File.temporary("/tmp/file_test");
///   // Use file.read() or file.write()
///   file.close();
///   File.delete(file.path);
/// ```
///
/// Reporting issues
/// ----------------
/// Please file an issue [in the issue
/// tracker](https://github.com/dartino/sdk/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
library file;

import 'dart:typed_data';

import 'package:os/os.dart';

final File _stdin = new File._('/dev/stdin', 0);
final File _stdout = new File._('/dev/stdout', 1);
final File _stderr = new File._('/dev/stderr', 2);

class File {
  static const int READ       = 0;
  static const int WRITE      = 1;
  static const int APPEND     = 2;
  static const int WRITE_ONLY = 3;

  static get stdin => _stdin;
  static get stdout => _stdout;
  static get stderr => _stderr;

  final String path;
  int _fd;

  /**
   * Create a new, opened File object, to work on the specified [path].
   *
   * A [FileException] is thrown if it was unable to open the specified file.
   */
  factory File.open(String path, {int mode: READ}) {
    if (mode < 0 || mode > 3) {
      throw new ArgumentError("Invalid open mode: $mode");
    }
    int fd = sys.open(path,
                      mode == APPEND || mode == READ || mode == WRITE,
                      mode == APPEND || mode == WRITE || mode == WRITE_ONLY,
                      mode == APPEND);
    if (fd == -1) throw new FileException("Failed to open file '$path'");
    return new File._(path, fd);
  }

  /**
   * Create and open a temporary file, using [path] as template.
   */
  factory File.temporary(String path) {
    TempFile temp = sys.mkstemp(path);
    int fd = temp.fd;
    if (fd == -1) {
      throw new FileException("Failed to create temporary file from '$path'");
    }
    return new File._(temp.path, fd);
  }

  File._(this.path, this._fd);

  /**
   * Return the file descriptor value for this file.
   *
   * This is especially useful in conjunction with `dart:fletch.ffi`. However it
   * should be used with care, as the `File` object assumes full control over the
   * file descriptor.
   */
  int get fd => _fd;

  /**
   * Write [buffer] to the file. The file must have been opened with [WRITE]
   * permissions.
   */
  void write(ByteBuffer buffer) {
    int result = sys.write(_fd, buffer, 0, buffer.lengthInBytes);
    if (result != buffer.lengthInBytes) _error("Failed to write buffer");
  }

  /**
   * Read up to [maxBytes] from the file.
   */
  ByteBuffer read(int maxBytes) {
    Uint8List list = new Uint8List(maxBytes);
    ByteBuffer buffer = list.buffer;
    int result = sys.read(_fd, buffer, 0, maxBytes);
    if (result == -1) _error("Failed to read from file");
    if (result < maxBytes) {
      Uint8List truncated = new Uint8List(result);
      ByteBuffer newBuffer = truncated.buffer;
      sys.memcpy(newBuffer, 0, buffer, 0, result);
      buffer = newBuffer;
    }
    return buffer;
  }

  /**
   * Get the current position within the file.
   */
  int get position {
    int value = sys.lseek(_fd, 0, SEEK_CUR);
    if (value == -1) _error("Failed to get the current file position");
    return value;
  }

  /**
   * Seek the position within the file.
   */
  void set position(int value) {
    if (sys.lseek(_fd, value, SEEK_SET) != value) {
      _error("Failed to set file offset to '$value'");
    }
  }

  /**
   * Get the length of the file.
   */
  int get length {
    int current = position;
    int end = sys.lseek(_fd, 0, SEEK_END);
    if (current == -1) _error("Failed to get file length");
    position = current;
    return end;
  }

  /**
   * Flush all data written to this file.
   */
  void flush() {
    // TODO(ajohnsen): Implement.
  }

  /**
   * Close the file.
   */
  void close() {
    _close();
  }

  /**
   * Returns true if the file is currently open.
   */
  bool get isOpen => _fd != -1;

  void _close() {
    if (_fd != -1) {
      sys.close(_fd);
      _fd = -1;
    }
  }

  void _error(String message) {
    _close();
    throw new FileException(message);
  }

  /**
   * Delete the file at [path] from disk.
   */
  static void delete(String path) {
    if (sys.unlink(path) == -1) {
      throw new FileException("Failed to remove file");
    }
  }

  /**
   * Returns true if the file exists.
   */
  // TODO(ajohnsen): This is the wrong implementation.
  static bool existsAsFile(String path) => sys.access(path) == 0;
}

class FileException implements Exception {
  final String message;

  FileException(this.message);

  String toString() => "FileException: $message";
}
