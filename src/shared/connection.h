// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_CONNECTION_H_
#define SRC_SHARED_CONNECTION_H_

#include "src/shared/globals.h"

namespace fletch {

class Socket;

class Buffer {
 public:
  Buffer();
  ~Buffer();

  void ClearBuffer();
  void SetBuffer(uint8* buffer, int length);

  int offset() const { return buffer_offset_; }

 protected:
  uint8* buffer_;
  int buffer_offset_;
  int buffer_length_;
};

class ReadBuffer : public Buffer {
 public:
  int ReadInt();
  int64 ReadInt64();
  double ReadDouble();
  bool ReadBoolean();
  uint8* ReadBytes(int* length);
};

class WriteBuffer : public Buffer {
 public:
  void EnsureCapacity(int bytes);
  void WriteInt(int value);
  void WriteInt64(int64 value);
  void WriteDouble(double value);
  void WriteBoolean(bool value);
  void WriteBytes(const uint8* bytes, int length);
  void WriteString(const char* str);
  void WriteTo(Socket* socket);
};

class Connection {
 public:
  enum Opcode {
    kConnectionError,
    kCompilerError,
    kSessionEnd,
    kForceTermination,

    kSpawnProcessForMain,
    kRunProcess,
    kWriteSnapshot,
    kCollectGarbage,

    kNewMap,
    kDeleteMap,
    kPushFromMap,
    kPopToMap,

    kDup,
    kDrop,
    kPushNull,
    kPushBoolean,
    kPushNewInteger,
    kPushNewDouble,
    kPushNewString,
    kPushNewInstance,
    kPushNewArray,
    kPushNewFunction,
    kPushNewInitializer,
    kPushNewClass,
    kPushBuiltinClass,
    kPushConstantList,
    kPushConstantMap,

    kPushNewName,

    kChangeSuperClass,
    kChangeMethodTable,
    kChangeMethodLiteral,
    kChangeStatics,
    kCommitChanges,
    kDiscardChanges,

    kUncaughtException,

    kMapLookup,
    kObjectId,

    kPopInteger,
    kInteger
  };

  static Connection* Connect(const char* host, int port);

  virtual ~Connection();

  int ReadInt() { return incoming_.ReadInt(); }
  int64 ReadInt64() { return incoming_.ReadInt64(); }
  double ReadDouble() { return incoming_.ReadDouble(); }
  bool ReadBoolean() { return incoming_.ReadBoolean(); }
  uint8* ReadBytes(int* length) { return incoming_.ReadBytes(length); }

  void WriteInt(int value) { outgoing_.WriteInt(value); }
  void WriteInt64(int64 value) { outgoing_.WriteInt64(value); }
  void WriteDouble(double value) { outgoing_.WriteDouble(value); }
  void WriteBoolean(bool value) { outgoing_.WriteBoolean(value); }
  void WriteBytes(const uint8* bytes, int length) {
    outgoing_.WriteBytes(bytes, length);
  }
  void WriteString(const char* str) { outgoing_.WriteString(str); }

  void Send(Opcode opcode);
  Opcode Receive();

 private:
  Socket* socket_;
  ReadBuffer incoming_;
  WriteBuffer outgoing_;

  friend class ConnectionListener;
  Connection(const char* host, int port, Socket* socket);
};

class ConnectionListener {
 public:
  ConnectionListener(const char* host, int port);
  virtual ~ConnectionListener();

  int Port();

  Connection* Accept();

 private:
  Socket* socket_;
  int port_;
};

}  // namespace fletch

#endif  // SRC_SHARED_CONNECTION_H_
