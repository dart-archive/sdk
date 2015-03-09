// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef BUILDBOT_SERVICE_H
#define BUILDBOT_SERVICE_H

#include <inttypes.h>
#include "struct.h"

class PresenterPatchSet;
class PresenterPatchSetBuilder;
class ConsoleNodeData;
class ConsoleNodeDataBuilder;
class CommitNodeData;
class CommitNodeDataBuilder;
class ConsolePatchSet;
class ConsolePatchSetBuilder;
class ConsoleNodePatchData;
class ConsoleNodePatchDataBuilder;
class CommitNodePatchData;
class CommitNodePatchDataBuilder;
class ListCommitNodePatchData;
class ListCommitNodePatchDataBuilder;
class StrData;
class StrDataBuilder;

class BuildBotService {
 public:
  static void setup();
  static void tearDown();
  static PresenterPatchSet refresh();
  static void refreshAsync(void (*callback)(PresenterPatchSet));
};

class PresenterPatchSet : public Reader {
 public:
  static const int kSize = 16;
  PresenterPatchSet(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isConsolePatchSet() const { return 1 == getTag(); }
  ConsolePatchSet getConsolePatchSet() const;
  uint16_t getTag() const { return *PointerTo<uint16_t>(8); }
};

class PresenterPatchSetBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit PresenterPatchSetBuilder(const Builder& builder)
      : Builder(builder) { }
  PresenterPatchSetBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  ConsolePatchSetBuilder initConsolePatchSet();
  void setTag(uint16_t value) { *PointerTo<uint16_t>(8) = value; }
};

class ConsoleNodeData : public Reader {
 public:
  static const int kSize = 24;
  ConsoleNodeData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  StrData getTitle() const;
  StrData getStatus() const;
  List<CommitNodeData> getCommits() const { return ReadList<CommitNodeData>(16); }
};

class ConsoleNodeDataBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit ConsoleNodeDataBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsoleNodeDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  StrDataBuilder initTitle();
  StrDataBuilder initStatus();
  List<CommitNodeDataBuilder> initCommits(int length);
};

class CommitNodeData : public Reader {
 public:
  static const int kSize = 24;
  CommitNodeData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  StrData getAuthor() const;
  StrData getMessage() const;
  int32_t getRevision() const { return *PointerTo<int32_t>(16); }
};

class CommitNodeDataBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit CommitNodeDataBuilder(const Builder& builder)
      : Builder(builder) { }
  CommitNodeDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  StrDataBuilder initAuthor();
  StrDataBuilder initMessage();
  void setRevision(int32_t value) { *PointerTo<int32_t>(16) = value; }
};

class ConsolePatchSet : public Reader {
 public:
  static const int kSize = 8;
  ConsolePatchSet(Segment* segment, int offset)
      : Reader(segment, offset) { }

  List<ConsoleNodePatchData> getPatches() const { return ReadList<ConsoleNodePatchData>(0); }
};

class ConsolePatchSetBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit ConsolePatchSetBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsolePatchSetBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<ConsoleNodePatchDataBuilder> initPatches(int length);
};

class ConsoleNodePatchData : public Reader {
 public:
  static const int kSize = 32;
  ConsoleNodePatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isReplace() const { return 1 == getTag(); }
  ConsoleNodeData getReplace() const;
  bool isTitle() const { return 2 == getTag(); }
  StrData getTitle() const;
  bool isStatus() const { return 3 == getTag(); }
  StrData getStatus() const;
  bool isCommits() const { return 4 == getTag(); }
  ListCommitNodePatchData getCommits() const;
  uint16_t getTag() const { return *PointerTo<uint16_t>(24); }
};

class ConsoleNodePatchDataBuilder : public Builder {
 public:
  static const int kSize = 32;

  explicit ConsoleNodePatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsoleNodePatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  ConsoleNodeDataBuilder initReplace();
  StrDataBuilder initTitle();
  StrDataBuilder initStatus();
  ListCommitNodePatchDataBuilder initCommits();
  void setTag(uint16_t value) { *PointerTo<uint16_t>(24) = value; }
};

class CommitNodePatchData : public Reader {
 public:
  static const int kSize = 24;
  CommitNodePatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isReplace() const { return 1 == getTag(); }
  CommitNodeData getReplace() const;
  bool isRevision() const { return 2 == getTag(); }
  int32_t getRevision() const { return *PointerTo<int32_t>(0); }
  bool isAuthor() const { return 3 == getTag(); }
  StrData getAuthor() const;
  bool isMessage() const { return 4 == getTag(); }
  StrData getMessage() const;
  uint16_t getTag() const { return *PointerTo<uint16_t>(20); }
};

class CommitNodePatchDataBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit CommitNodePatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  CommitNodePatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  CommitNodeDataBuilder initReplace();
  void setRevision(int32_t value) { setTag(2); *PointerTo<int32_t>(0) = value; }
  StrDataBuilder initAuthor();
  StrDataBuilder initMessage();
  void setTag(uint16_t value) { *PointerTo<uint16_t>(20) = value; }
};

class ListCommitNodePatchData : public Reader {
 public:
  static const int kSize = 16;
  ListCommitNodePatchData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isReplace() const { return 1 == getTag(); }
  List<CommitNodeData> getReplace() const { return ReadList<CommitNodeData>(0); }
  uint16_t getTag() const { return *PointerTo<uint16_t>(8); }
};

class ListCommitNodePatchDataBuilder : public Builder {
 public:
  static const int kSize = 16;

  explicit ListCommitNodePatchDataBuilder(const Builder& builder)
      : Builder(builder) { }
  ListCommitNodePatchDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<CommitNodeDataBuilder> initReplace(int length);
  void setTag(uint16_t value) { *PointerTo<uint16_t>(8) = value; }
};

class StrData : public Reader {
 public:
  static const int kSize = 8;
  StrData(Segment* segment, int offset)
      : Reader(segment, offset) { }

  List<uint8_t> getChars() const { return ReadList<uint8_t>(0); }
};

class StrDataBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit StrDataBuilder(const Builder& builder)
      : Builder(builder) { }
  StrDataBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<uint8_t> initChars(int length);
};

#endif  // BUILDBOT_SERVICE_H
