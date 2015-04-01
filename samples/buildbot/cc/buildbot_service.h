// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef BUILDBOT_SERVICE_H
#define BUILDBOT_SERVICE_H

#include <inttypes.h>
#include "struct.h"

class ConsoleNodeData;
class ConsoleNodeDataBuilder;
class CommitNodeData;
class CommitNodeDataBuilder;
class BuildBotPatchData;
class BuildBotPatchDataBuilder;
class ConsolePatchData;
class ConsolePatchDataBuilder;
class ConsoleUpdatePatchData;
class ConsoleUpdatePatchDataBuilder;
class CommitPatchData;
class CommitPatchDataBuilder;
class CommitUpdatePatchData;
class CommitUpdatePatchDataBuilder;
class CommitListPatchData;
class CommitListPatchDataBuilder;
class CommitListUpdatePatchData;
class CommitListUpdatePatchDataBuilder;

class BuildBotService {
 public:
  static void setup();
  static void tearDown();
  static BuildBotPatchData refresh();
  static void refreshAsync(void (*callback)(BuildBotPatchData));
};

class ConsoleNodeData : public Reader {
 public:
  static const int kSize = 24;
  ConsoleNodeData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  char* getTitle() const { return ReadString(0); }
  List<uint16_t> getTitleData() const { return ReadList<uint16_t>(0); }
  char* getStatus() const { return ReadString(8); }
  List<uint16_t> getStatusData() const { return ReadList<uint16_t>(8); }
  List<CommitNodeData> getCommits() const { return ReadList<CommitNodeData>(16); }
};

class ConsoleNodeDataBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit ConsoleNodeDataBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsoleNodeDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setTitle(const char* value) { NewString(0, value); }
  List<uint16_t> initTitleData(int length);
  void setStatus(const char* value) { NewString(8, value); }
  List<uint16_t> initStatusData(int length);
  List<CommitNodeDataBuilder> initCommits(int length);
};

class CommitNodeData : public Reader {
 public:
  static const int kSize = 24;
  CommitNodeData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  char* getAuthor() const { return ReadString(0); }
  List<uint16_t> getAuthorData() const { return ReadList<uint16_t>(0); }
  char* getMessage() const { return ReadString(8); }
  List<uint16_t> getMessageData() const { return ReadList<uint16_t>(8); }
  int32_t getRevision() const { return *PointerTo<int32_t>(16); }
};

class CommitNodeDataBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit CommitNodeDataBuilder(const Builder& builder)
      : Builder(builder) { }
  CommitNodeDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setAuthor(const char* value) { NewString(0, value); }
  List<uint16_t> initAuthorData(int length);
  void setMessage(const char* value) { NewString(8, value); }
  List<uint16_t> initMessageData(int length);
  void setRevision(int32_t value) { *PointerTo<int32_t>(16) = value; }
};

class BuildBotPatchData : public Reader {
 public:
  static const int kSize = 32;
  BuildBotPatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isNoPatch() const { return 1 == getTag(); }
  bool isConsolePatch() const { return 2 == getTag(); }
  ConsolePatchData getConsolePatch() const;
  uint16_t getTag() const { return *PointerTo<uint16_t>(26); }
};

class BuildBotPatchDataBuilder : public Builder {
 public:
  static const int kSize = 32;

  explicit BuildBotPatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  BuildBotPatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setNoPatch() { setTag(1); }
  ConsolePatchDataBuilder initConsolePatch();
  void setTag(uint16_t value) { *PointerTo<uint16_t>(26) = value; }
};

class ConsolePatchData : public Reader {
 public:
  static const int kSize = 32;
  ConsolePatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isReplace() const { return 1 == getTag(); }
  ConsoleNodeData getReplace() const;
  bool isUpdates() const { return 2 == getTag(); }
  List<ConsoleUpdatePatchData> getUpdates() const { return ReadList<ConsoleUpdatePatchData>(0); }
  uint16_t getTag() const { return *PointerTo<uint16_t>(24); }
};

class ConsolePatchDataBuilder : public Builder {
 public:
  static const int kSize = 32;

  explicit ConsolePatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsolePatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  ConsoleNodeDataBuilder initReplace();
  List<ConsoleUpdatePatchDataBuilder> initUpdates(int length);
  void setTag(uint16_t value) { *PointerTo<uint16_t>(24) = value; }
};

class ConsoleUpdatePatchData : public Reader {
 public:
  static const int kSize = 16;
  ConsoleUpdatePatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isTitle() const { return 1 == getTag(); }
  char* getTitle() const { return ReadString(0); }
  List<uint16_t> getTitleData() const { return ReadList<uint16_t>(0); }
  bool isStatus() const { return 2 == getTag(); }
  char* getStatus() const { return ReadString(0); }
  List<uint16_t> getStatusData() const { return ReadList<uint16_t>(0); }
  bool isCommits() const { return 3 == getTag(); }
  CommitListPatchData getCommits() const;
  uint16_t getTag() const { return *PointerTo<uint16_t>(8); }
};

class ConsoleUpdatePatchDataBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit ConsoleUpdatePatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsoleUpdatePatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setTitle(const char* value) { setTag(1); NewString(0, value); }
  List<uint16_t> initTitleData(int length);
  void setStatus(const char* value) { setTag(2); NewString(0, value); }
  List<uint16_t> initStatusData(int length);
  CommitListPatchDataBuilder initCommits();
  void setTag(uint16_t value) { *PointerTo<uint16_t>(8) = value; }
};

class CommitPatchData : public Reader {
 public:
  static const int kSize = 24;
  CommitPatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isReplace() const { return 1 == getTag(); }
  CommitNodeData getReplace() const;
  bool isUpdates() const { return 2 == getTag(); }
  List<CommitUpdatePatchData> getUpdates() const { return ReadList<CommitUpdatePatchData>(0); }
  uint16_t getTag() const { return *PointerTo<uint16_t>(20); }
};

class CommitPatchDataBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit CommitPatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  CommitPatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  CommitNodeDataBuilder initReplace();
  List<CommitUpdatePatchDataBuilder> initUpdates(int length);
  void setTag(uint16_t value) { *PointerTo<uint16_t>(20) = value; }
};

class CommitUpdatePatchData : public Reader {
 public:
  static const int kSize = 16;
  CommitUpdatePatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isRevision() const { return 1 == getTag(); }
  int32_t getRevision() const { return *PointerTo<int32_t>(0); }
  bool isAuthor() const { return 2 == getTag(); }
  char* getAuthor() const { return ReadString(0); }
  List<uint16_t> getAuthorData() const { return ReadList<uint16_t>(0); }
  bool isMessage() const { return 3 == getTag(); }
  char* getMessage() const { return ReadString(0); }
  List<uint16_t> getMessageData() const { return ReadList<uint16_t>(0); }
  uint16_t getTag() const { return *PointerTo<uint16_t>(8); }
};

class CommitUpdatePatchDataBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit CommitUpdatePatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  CommitUpdatePatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setRevision(int32_t value) { setTag(1); *PointerTo<int32_t>(0) = value; }
  void setAuthor(const char* value) { setTag(2); NewString(0, value); }
  List<uint16_t> initAuthorData(int length);
  void setMessage(const char* value) { setTag(3); NewString(0, value); }
  List<uint16_t> initMessageData(int length);
  void setTag(uint16_t value) { *PointerTo<uint16_t>(8) = value; }
};

class CommitListPatchData : public Reader {
 public:
  static const int kSize = 8;
  CommitListPatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  List<CommitListUpdatePatchData> getUpdates() const { return ReadList<CommitListUpdatePatchData>(0); }
};

class CommitListPatchDataBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit CommitListPatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  CommitListPatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<CommitListUpdatePatchDataBuilder> initUpdates(int length);
};

class CommitListUpdatePatchData : public Reader {
 public:
  static const int kSize = 16;
  CommitListUpdatePatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isInsert() const { return 1 == getTag(); }
  List<CommitNodeData> getInsert() const { return ReadList<CommitNodeData>(0); }
  bool isPatch() const { return 2 == getTag(); }
  List<CommitPatchData> getPatch() const { return ReadList<CommitPatchData>(0); }
  bool isRemove() const { return 3 == getTag(); }
  uint32_t getRemove() const { return *PointerTo<uint32_t>(0); }
  uint32_t getIndex() const { return *PointerTo<uint32_t>(8); }
  uint16_t getTag() const { return *PointerTo<uint16_t>(12); }
};

class CommitListUpdatePatchDataBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit CommitListUpdatePatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  CommitListUpdatePatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<CommitNodeDataBuilder> initInsert(int length);
  List<CommitPatchDataBuilder> initPatch(int length);
  void setRemove(uint32_t value) { setTag(3); *PointerTo<uint32_t>(0) = value; }
  void setIndex(uint32_t value) { *PointerTo<uint32_t>(8) = value; }
  void setTag(uint16_t value) { *PointerTo<uint16_t>(12) = value; }
};

#endif  // BUILDBOT_SERVICE_H
