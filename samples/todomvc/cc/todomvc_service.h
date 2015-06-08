// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef TODOMVC_SERVICE_H
#define TODOMVC_SERVICE_H

#include <inttypes.h>
#include "struct.h"

class Node;
class NodeBuilder;
class Cons;
class ConsBuilder;
class Patch;
class PatchBuilder;
class PatchSet;
class PatchSetBuilder;
class BoxedString;
class BoxedStringBuilder;

class TodoMVCService {
 public:
  static void setup();
  static void tearDown();
  static void createItem(BoxedStringBuilder title);
  static void createItemAsync(BoxedStringBuilder title, void (*callback)(void*), void* callback_data);
  static void deleteItem(int32_t id);
  static void deleteItemAsync(int32_t id, void (*callback)(void*), void* callback_data);
  static void completeItem(int32_t id);
  static void completeItemAsync(int32_t id, void (*callback)(void*), void* callback_data);
  static void uncompleteItem(int32_t id);
  static void uncompleteItemAsync(int32_t id, void (*callback)(void*), void* callback_data);
  static void clearItems();
  static void clearItemsAsync(void (*callback)(void*), void* callback_data);
  static void dispatch(uint16_t id);
  static void dispatchAsync(uint16_t id, void (*callback)(void*), void* callback_data);
  static PatchSet sync();
  static void syncAsync(void (*callback)(PatchSet, void*), void* callback_data);
  static void reset();
  static void resetAsync(void (*callback)(void*), void* callback_data);
};

class Node : public Reader {
 public:
  static const int kSize = 24;
  Node(Segment* segment, int offset)
      : Reader(segment, offset) { }

  bool isNil() const { return 1 == getTag(); }
  bool isNum() const { return 2 == getTag(); }
  int32_t getNum() const { return *PointerTo<int32_t>(0); }
  bool isTruth() const { return 3 == getTag(); }
  bool getTruth() const { return *PointerTo<uint8_t>(0) != 0; }
  bool isStr() const { return 4 == getTag(); }
  char* getStr() const { return ReadString(0); }
  List<uint16_t> getStrData() const { return ReadList<uint16_t>(0); }
  bool isCons() const { return 5 == getTag(); }
  Cons getCons() const;
  uint16_t getTag() const { return *PointerTo<uint16_t>(22); }
};

class NodeBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit NodeBuilder(const Builder& builder)
      : Builder(builder) { }
  NodeBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setNil() { setTag(1); }
  void setNum(int32_t value) { setTag(2); *PointerTo<int32_t>(0) = value; }
  void setTruth(bool value) { setTag(3); *PointerTo<uint8_t>(0) = value ? 1 : 0; }
  void setStr(const char* value) { setTag(4); NewString(0, value); }
  List<uint16_t> initStrData(int length);
  ConsBuilder initCons();
  void setTag(uint16_t value) { *PointerTo<uint16_t>(22) = value; }
};

class Cons : public Reader {
 public:
  static const int kSize = 24;
  Cons(Segment* segment, int offset)
      : Reader(segment, offset) { }

  Node getFst() const;
  Node getSnd() const;
  uint16_t getDeleteEvent() const { return *PointerTo<uint16_t>(16); }
  uint16_t getCompleteEvent() const { return *PointerTo<uint16_t>(18); }
  uint16_t getUncompleteEvent() const { return *PointerTo<uint16_t>(20); }
};

class ConsBuilder : public Builder {
 public:
  static const int kSize = 24;

  explicit ConsBuilder(const Builder& builder)
      : Builder(builder) { }
  ConsBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  NodeBuilder initFst();
  NodeBuilder initSnd();
  void setDeleteEvent(uint16_t value) { *PointerTo<uint16_t>(16) = value; }
  void setCompleteEvent(uint16_t value) { *PointerTo<uint16_t>(18) = value; }
  void setUncompleteEvent(uint16_t value) { *PointerTo<uint16_t>(20) = value; }
};

class Patch : public Reader {
 public:
  static const int kSize = 32;
  Patch(Segment* segment, int offset)
      : Reader(segment, offset) { }

  Node getContent() const;
  List<uint8_t> getPath() const { return ReadList<uint8_t>(24); }
};

class PatchBuilder : public Builder {
 public:
  static const int kSize = 32;

  explicit PatchBuilder(const Builder& builder)
      : Builder(builder) { }
  PatchBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  NodeBuilder initContent();
  List<uint8_t> initPath(int length);
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

class BoxedString : public Reader {
 public:
  static const int kSize = 8;
  BoxedString(Segment* segment, int offset)
      : Reader(segment, offset) { }

  char* getStr() const { return ReadString(0); }
  List<uint16_t> getStrData() const { return ReadList<uint16_t>(0); }
};

class BoxedStringBuilder : public Builder {
 public:
  static const int kSize = 8;

  explicit BoxedStringBuilder(const Builder& builder)
      : Builder(builder) { }
  BoxedStringBuilder(Segment* segment, int offset)
      : Builder(segment, offset) { }

  void setStr(const char* value) { NewString(0, value); }
  List<uint16_t> initStrData(int length);
};

#endif  // TODOMVC_SERVICE_H
