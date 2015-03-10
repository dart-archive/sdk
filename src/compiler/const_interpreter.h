// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_CONST_INTERPRETER_H_
#define SRC_COMPILER_CONST_INTERPRETER_H_

#include "src/compiler/compiler.h"
#include "src/compiler/list_builder.h"
#include "src/compiler/map.h"
#include "src/compiler/tree.h"
#include "src/compiler/zone.h"

namespace fletch {

class Compiler;
class ConstNull;
class ConstTrue;
class ConstFalse;
class ConstInteger;
class ConstDouble;
class ConstString;
class ConstList;
class ConstMap;
class ConstClass;

class ConstObjectVisitor : public StackAllocated {
 public:
  virtual ~ConstObjectVisitor() {}
  virtual void DoNull(ConstNull* object) {}
  virtual void DoTrue(ConstTrue* object) {}
  virtual void DoFalse(ConstFalse* object) {}
  virtual void DoInteger(ConstInteger* object) {}
  virtual void DoDouble(ConstDouble* object) {}
  virtual void DoString(ConstString* object) {}
  virtual void DoList(ConstList* object) {}
  virtual void DoMap(ConstMap* object) {}
  virtual void DoClass(ConstClass* object) {}
};

class ConstObject : public ZoneAllocated {
 public:
  explicit ConstObject(int id) : id_(id) {}
  virtual ~ConstObject() {}

  int id() const { return id_; }

  virtual void Accept(ConstObjectVisitor* visitor) = 0;

  virtual const ConstInteger* AsInteger() const { return NULL; }
  virtual const ConstDouble* AsDouble() const { return NULL; }
  virtual const ConstTrue* AsTrue() const { return NULL; }
  virtual const ConstFalse* AsFalse() const { return NULL; }

 private:
  const int id_;
};

class ConstNull : public ConstObject {
 public:
  explicit ConstNull(int id) : ConstObject(id) {
  }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoNull(this);
  }
};

class ConstTrue : public ConstObject {
 public:
  explicit ConstTrue(int id) : ConstObject(id) {
  }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoTrue(this);
  }

  virtual const ConstTrue* AsTrue() const { return this; }
};

class ConstFalse : public ConstObject {
 public:
  explicit ConstFalse(int id) : ConstObject(id) {
  }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoFalse(this);
  }

  virtual const ConstFalse* AsFalse() const { return this; }
};

class ConstInteger : public ConstObject {
 public:
  ConstInteger(int id, int64 value)
      : ConstObject(id)
      , value_(value) {
  }

  int64 value() const { return value_; }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoInteger(this);
  }

  const ConstInteger* AsInteger() const { return this; }

 private:
  const int64 value_;
};

class ConstDouble : public ConstObject {
 public:
  ConstDouble(int id, double value)
      : ConstObject(id)
      , value_(value) {
  }

  double value() const { return value_; }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoDouble(this);
  }

  const ConstDouble* AsDouble() const { return this; }

 private:
  const double value_;
};

class ConstString : public ConstObject {
 public:
  ConstString(int id, const char* value)
      : ConstObject(id)
      , value_(value) {
  }

  const char* value() const { return value_; }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoString(this);
  }

 private:
  const char* const value_;
};

class PartialConstList : public IdMap<PartialConstList*> {
 public:
  explicit PartialConstList(Zone* zone)
      : IdMap(zone, 0)
      , list_(NULL) {}

  ConstList* list() const { return list_; }
  void set_list(ConstList* value) { list_ = value; }

 private:
  ConstList* list_;
};

class ConstList : public ConstObject {
 public:
  explicit ConstList(int id, List<ConstObject*> elements)
      : ConstObject(id)
      , elements_(elements) {
  }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoList(this);
  }

  List<ConstObject*> elements() const { return elements_; }

 private:
  List<ConstObject*> elements_;
};

class PartialConstMap : public IdMap<PartialConstMap*> {
 public:
  explicit PartialConstMap(Zone* zone)
      : IdMap(zone, 0)
      , map_(NULL) {}

  ConstMap* map() const { return map_; }
  void set_map(ConstMap* value) { map_ = value; }

 private:
  ConstMap* map_;
};

class ConstMap : public ConstObject {
 public:
  explicit ConstMap(int id, List<ConstObject*> elements)
      : ConstObject(id)
      , elements_(elements) {
  }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoMap(this);
  }

  List<ConstObject*> elements() const { return elements_; }

 private:
  List<ConstObject*> elements_;
};

class PartialConstClass : public IdMap<PartialConstClass*> {
 public:
  explicit PartialConstClass(Zone* zone)
      : IdMap(zone, 0)
      , clazz_(NULL) {}

  ConstClass* clazz() const { return clazz_; }
  void set_clazz(ConstClass* value) { clazz_ = value; }

 private:
  ConstClass* clazz_;
};

class ConstClass : public ConstObject {
 public:
  explicit ConstClass(int id, ClassNode* node, List<ConstObject*> fields)
      : ConstObject(id)
      , node_(node)
      , fields_(fields) {
  }

  ClassNode* node() const { return node_; }

  void Accept(ConstObjectVisitor* visitor) {
    visitor->DoClass(this);
  }

  List<ConstObject*> fields() const { return fields_; }

 private:
  ClassNode* node_;
  List<ConstObject*> fields_;
};

class ConstInterpreter : public ZoneAllocated {
 public:
  static const int kConstNullId  = 0;
  static const int kConstTrueId  = 1;
  static const int kConstFalseId = 2;

  class ConstVisitor : public TreeVisitor {
   public:
    ConstVisitor(ConstInterpreter* const_interpreter, Scope* scope);

    void DoBinary(BinaryNode* node);
    void DoUnary(UnaryNode* node);
    void DoParenthesized(ParenthesizedNode* node);

    void DoLiteralInteger(LiteralIntegerNode* node);
    void DoLiteralDouble(LiteralDoubleNode* node);
    void DoLiteralString(LiteralStringNode* node);
    void DoLiteralList(LiteralListNode* node);
    void DoLiteralMap(LiteralMapNode* node);
    void DoNew(NewNode* node);
    void DoNull(NullNode* node);
    void DoLiteralBoolean(LiteralBooleanNode* node);
    void DoIdentifier(IdentifierNode* node);
    void DoDot(DotNode* node);
    void DoConditional(ConditionalNode* node);

    ConstObject* Pop() { return stack_.RemoveLast(); }
    bool IsResolved() const { return stack_.length() == 1; }

    ConstObject* Resolve(TreeNode* node, Scope* scope = NULL);

   private:
    ConstInterpreter* const_interpreter_;
    Scope* scope_;
    ListBuilder<ConstObject*, 8> stack_;

    void Push(ConstObject* object) { stack_.Add(object); }

    ConstInterpreter* const_interpreter() const { return const_interpreter_; }
    Scope* scope() const { return scope_; }
    Zone* zone() const { return const_interpreter()->zone(); }
  };

  explicit ConstInterpreter(Compiler* compiler);

  int Interpret(TreeNode* node, Scope* scope);
  int CreateConstInstance(ClassNode* clazz);

  List<ConstObject*> const_objects() { return const_objects_.ToList(); }

  Compiler* compiler() const { return compiler_; }
  Zone* zone() const { return compiler()->zone(); }

 private:
  static int DoubleHash(const double value);
  static bool DoubleEquals(const double a, const double b);

  ConstInteger* FindInteger(int64 value);
  ConstDouble* FindDouble(double value);

  Compiler* compiler_;
  ListBuilder<ConstObject*, 16> const_objects_;
  IntegerMap<ConstInteger*> integer_map_;
  Map<double, ConstDouble*, DoubleHash, DoubleEquals> double_map_;
  StringMap<ConstString*> string_map_;
  IdMap<PartialConstList*> list_map_;
  IdMap<PartialConstMap*> map_map_;
  IdMap<PartialConstClass*> class_map_;
  ConstNull* const_null_;
  ConstTrue* const_true_;
  ConstFalse* const_false_;

  ConstObject* const_null() const { return const_null_; }
};

}  // namespace fletch

#endif  // SRC_COMPILER_CONST_INTERPRETER_H_
