// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_LIVE_CODING

#include "src/shared/connection.h"

#include "src/shared/assert.h"
#include "src/shared/globals.h"
#include "src/shared/native_socket.h"
#include "src/shared/utils.h"

namespace fletch {

// TODO(ager,ajohnsen): Instead of dynamically allocating the actual
// buffer, we can get away with inline allocation of a small buffer
// and only use dynamic allocation if that inline buffer doesn't have
// a large enough capacity.
static const int kBufferGrowthSize = 64;

Buffer::Buffer() : buffer_(NULL), buffer_offset_(0), buffer_length_(0) {}

Buffer::~Buffer() { free(buffer_); }

void Buffer::ClearBuffer() {
  ASSERT(buffer_offset_ == buffer_length_);
  free(buffer_);
  buffer_ = NULL;
}

void Buffer::SetBuffer(uint8* buffer, int length) {
  buffer_ = buffer;
  buffer_offset_ = 0;
  buffer_length_ = length;
}

void WriteBuffer::EnsureCapacity(int bytes) {
  if (buffer_offset_ + bytes <= buffer_length_) return;
  int increment = Utils::Maximum(bytes, kBufferGrowthSize);
  buffer_length_ += increment;
  buffer_ = static_cast<uint8*>(realloc(buffer_, buffer_length_));
}

void WriteBuffer::WriteInt(int value) {
  EnsureCapacity(4);
  Utils::WriteInt32(buffer_ + buffer_offset_, value);
  buffer_offset_ += 4;
}

void WriteBuffer::WriteInt64(int64 value) {
  EnsureCapacity(8);
  Utils::WriteInt64(buffer_ + buffer_offset_, value);
  buffer_offset_ += 8;
}

void WriteBuffer::WriteDouble(double value) {
  WriteInt64(bit_cast<int64>(value));
}

void WriteBuffer::WriteBoolean(bool value) {
  EnsureCapacity(1);
  buffer_[buffer_offset_++] = value ? 1 : 0;
}

void WriteBuffer::WriteBytes(const uint8* bytes, int length) {
  WriteInt(length);
  EnsureCapacity(length);
  memcpy(buffer_ + buffer_offset_, bytes, length);
  buffer_offset_ += length;
}

void WriteBuffer::WriteString(const char* str) {
  int length = strlen(str);
  EnsureCapacity(length);
  memcpy(buffer_ + buffer_offset_, str, length);
  buffer_offset_ += length;
}

void WriteBuffer::WriteTo(Socket* socket) const {
  if (buffer_offset_ == 0) return;
  socket->Write(buffer_, buffer_offset_);
}

int ReadBuffer::ReadInt() {
  ASSERT(buffer_offset_ + 4 <= buffer_length_);
  int value = Utils::ReadInt32(buffer_ + buffer_offset_);
  buffer_offset_ += 4;
  return value;
}

int64 ReadBuffer::ReadInt64() {
  ASSERT(buffer_offset_ + 8 <= buffer_length_);
  int64 value = Utils::ReadInt64(buffer_ + buffer_offset_);
  buffer_offset_ += 8;
  return value;
}

double ReadBuffer::ReadDouble() { return bit_cast<double>(ReadInt64()); }

bool ReadBuffer::ReadBoolean() {
  ASSERT(buffer_offset_ + 1 <= buffer_length_);
  return buffer_[buffer_offset_++] == 1;
}

uint8* ReadBuffer::ReadBytes(int* length) {
  int len = ReadInt();
  ASSERT(buffer_offset_ + len <= buffer_length_);
  *length = len;
  uint8* buffer = static_cast<uint8*>(malloc(len));
  memcpy(buffer, buffer_ + buffer_offset_, len);
  buffer_offset_ += len;
  return buffer;
}

Connection* Connection::Connect(const char* host, int port) {
  Socket* socket = new Socket();

  if (socket->Connect(host, port)) {
    // We send many small packages, so use no-delay.
    socket->SetTCPNoDelay(true);
    return new Connection(host, port, socket);
  }

  Print::Error("Failed to connect to %s:%i\n", host, port);
  UNREACHABLE();
  return NULL;
}

Connection::~Connection() {
  delete send_mutex_;
  delete socket_;
}

Connection::Opcode Connection::Receive() {
  incoming_.ClearBuffer();
  uint8* bytes = socket_->Read(5);
  if (bytes == NULL) return kConnectionError;
  int buffer_length = Utils::ReadInt32(bytes);
  Opcode opcode = static_cast<Opcode>(bytes[4]);
  free(bytes);
  if (buffer_length > 0) {
    uint8* buffer = socket_->Read(buffer_length);
    incoming_.SetBuffer(buffer, buffer_length);
    if (buffer == NULL) return kConnectionError;
  }
  return opcode;
}

void Connection::Send(Opcode opcode, const WriteBuffer& buffer) {
  ScopedLock scoped_lock(send_mutex_);
  uint8 header[5];
  Utils::WriteInt32(header, buffer.offset());
  header[4] = opcode;
  socket_->Write(header, 5);
  buffer.WriteTo(socket_);
}

Connection::Connection(const char* host, int port, Socket* socket)
    : socket_(socket), send_mutex_(Platform::CreateMutex()) {}

ConnectionListener::ConnectionListener(const char* host, int port)
    : socket_(new Socket()), port_(-1) {
  socket_->Bind(host, port);
  port_ = socket_->Listen();
}

ConnectionListener::~ConnectionListener() { delete socket_; }

int ConnectionListener::Port() { return port_; }

Connection* ConnectionListener::Accept() {
  Socket* child = socket_->Accept();
  return new Connection("", 0, child);
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING
