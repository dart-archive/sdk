// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.io;

class File {
  static const int READ   = 1 << 1;
  static const int WRITE  = 1 << 2;
  static const int APPEND = 1 << 3;

  /**
   * Create a new File object, to work on the specified [file].
   *
   */
  File(String name);

  /**
   * Create a new, opened File object, to work on the specified [file].
   *
   * A [FileException] is thrown if it was unable to open the specified file.
   */
  factory File.opened(String name, {int mode: READ});

  /**
   * Open the file pointed to by this file object.
   *
   * A [FileException] is thrown if it was unable to open the specified file.
   */
  void open({int mode: READ});

  /**
   * Write [buffer] to the file. The file must have been opened with [WRITE]
   * permissions.
   */
  void write(ByteBuffer buffer);

  /**
   * Read up to [maxBytes] from the file.
   */
  ByteBuffer read(int maxBytes);

  /**
   * Get the current position within the file.
   */
  int get position;

  /**
   * Seek the position within the file.
   */
  void set position(int value);

  /**
   * Get the length of the file.
   */
  int get length;

  /**
   * Flush all data written to this file.
   */
  void flush();

  /**
   * Close the file.
   */
  void close();
}

class FileException implements Exception {
}
