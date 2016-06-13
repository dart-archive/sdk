// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_CONNECTION_H_
#define SRC_SHARED_CONNECTION_H_

#include "src/shared/globals.h"
#include "src/shared/platform.h"

namespace dartino {

class Socket;

class Buffer {
 public:
  Buffer();
  ~Buffer();

  void ClearBuffer();
  void SetBuffer(uint8* buffer, int length);
  uint8* GetBuffer() const;

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
};

class Connection {
 public:
  // Any change in [Opcode] must also be done in [VMCommandError] in
  // pkg/dartino_compiler/lib/vm_commands.dart.
  enum ErrorCode {
    kInvalidInstanceAccess,
    kSnapshotCreationError,
  };

  // Any change in [Opcode] must also be done in [VMCommandCode] in
  // pkg/dartino_compiler/lib/vm_commands.dart.
  enum Opcode {
    // DO NOT MOVE! The handshake opcodes needs to be the first one as
    // it is used to verify the compiler and vm versions.
    kHandShake,
    kHandShakeResult,

    kConnectionError,
    kCompilerError,
    kSessionEnd,
    kLiveEditing,
    kDebugging,
    kDebuggingReply,
    kDisableStandardOutput,
    kStdoutData,
    kStderrData,

    kProcessDebugInterrupt,
    kProcessSpawnForMain,
    kProcessRun,
    kProcessSetBreakpoint,
    kProcessDeleteBreakpoint,
    kProcessDeleteOneShotBreakpoint,
    kProcessStep,
    kProcessStepOver,
    kProcessStepOut,
    kProcessStepTo,
    kProcessContinue,
    kProcessBacktraceRequest,
    kProcessFiberBacktraceRequest,
    kProcessBacktrace,
    kProcessUncaughtExceptionRequest,
    kProcessBreakpoint,
    kProcessInstance,
    kProcessInstanceStructure,
    kProcessRestartFrame,
    kProcessTerminated,
    kProcessCompileTimeError,
    kProcessAddFibersToMap,
    kProcessNumberOfStacks,
    kCommandError,

    kProcessGetProcessIds,
    kProcessGetProcessIdsResult,

    kSetEntryPoint,
    kCreateSnapshot,
    kProgramInfo,
    kCollectGarbage,

    kNewMap,
    kDeleteMap,
    kPushFromMap,
    kPopToMap,
    kRemoveFromMap,

    kDup,
    kDrop,
    kPushNull,
    kPushBoolean,
    kPushNewInteger,
    kPushNewBigInteger,
    kPushNewDouble,
    kPushNewOneByteString,
    kPushNewTwoByteString,
    kPushNewInstance,
    kPushNewArray,
    kPushNewFunction,
    kPushNewInitializer,
    kPushNewClass,
    kPushBuiltinClass,
    kPushConstantList,
    kPushConstantByteList,
    kPushConstantMap,

    kChangeSuperClass,
    kChangeMethodTable,
    kChangeMethodLiteral,
    kChangeStatics,
    kChangeSchemas,

    kPrepareForChanges,
    kCommitChanges,
    kCommitChangesResult,
    kDiscardChanges,

    kUncaughtException,

    kMapLookup,
    kObjectId,

    kInteger,
    kBoolean,
    kNull,
    kDouble,
    kString,
    kInstance,
    kClass,
    kInstanceStructure
  };

  Connection();
  virtual ~Connection();

  int ReadInt() { return incoming_.ReadInt(); }
  int64 ReadInt64() { return incoming_.ReadInt64(); }
  double ReadDouble() { return incoming_.ReadDouble(); }
  bool ReadBoolean() { return incoming_.ReadBoolean(); }
  uint8* ReadBytes(int* length) { return incoming_.ReadBytes(length); }

  virtual void Send(Opcode opcode, const WriteBuffer& buffer) = 0;
  virtual Opcode Receive() = 0;

 protected:
  ReadBuffer incoming_;
  Mutex* send_mutex_;
};

}  // namespace dartino

#endif  // SRC_SHARED_CONNECTION_H_
