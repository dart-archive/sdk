// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef BUILDBOT_SERVICE_H
#define BUILDBOT_SERVICE_H

#include <inttypes.h>
#include "struct.h"

class Node;
class NodeBuilder;
class Str;
class StrBuilder;
class Patch;
class PatchBuilder;
class PatchSet;
class PatchSetBuilder;

class BuildBotService {
 public:
  static void setup();
  static void tearDown();
  static PatchSet sync();
  static void syncAsync(void (*callback)(PatchSet));
};

class Node : public Reader {
 public:
  static const int kSize = 0;
  Node(Segment* segment, int offset)
      : Reader(segment, offset) { }

};

class NodeBuilder : public Builder {
 public:
  static const int kSize = 0;

  explicit NodeBuilder(const Builder& builder)
      : Builder(builder) { }
  NodeBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

};

class Str : public Reader {
 public:
  static const int kSize = 8;
  Str(Segment* segment, int offset)
      : Reader(segment, offset) { }

  List<uint8_t> getChars() const { return ReadList<uint8_t>(0); }
};

class StrBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit StrBuilder(const Builder& builder)
      : Builder(builder) { }
  StrBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<uint8_t> initChars(int length);
};

class Patch : public Reader {
 public:
  static const int kSize = 8;
  Patch(Segment* segment, int offset)
      : Reader(segment, offset) { }

  List<uint8_t> getPath() const { return ReadList<uint8_t>(0); }
  Node getContent() const;
};

class PatchBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit PatchBuilder(const Builder& builder)
      : Builder(builder) { }
  PatchBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<uint8_t> initPath(int length);
  NodeBuilder initContent();
};

class PatchSet : public Reader {
 public:
  static const int kSize = 8;
  PatchSet(Segment* segment, int offset)
      : Reader(segment, offset) { }

  List<Patch> getPatches() const { return ReadList<Patch>(0); }
};

class PatchSetBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit PatchSetBuilder(const Builder& builder)
      : Builder(builder) { }
  PatchSetBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  List<PatchBuilder> initPatches(int length);
};

#endif  // BUILDBOT_SERVICE_H
