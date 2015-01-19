// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/compiler/builder.h"
#include "src/shared/test_case.h"
#include "src/compiler/pretty_printer.h"
#include "src/compiler/zone.h"

namespace fletch {

const char* Build(Zone* zone, const char* source) {
  Builder builder(zone);
  Location location = builder.source()->LoadFromBuffer("<test_source>",
                                                       source,
                                                       strlen(source));
  CompilationUnitNode* unit = builder.BuildUnit(location);
  PrettyPrinter printer(zone);
  unit->Accept(&printer);
  return printer.Output();
}

TEST_CASE(SimpleMethod) {
  Zone zone;
  EXPECT_STREQ(
        "main(){{}}",
        Build(&zone, "main() { { } }"));
  EXPECT_STREQ(
        "main(){x;}",
        Build(&zone, "main() { x; }"));

  EXPECT_STREQ(
      "main(){return;}",
      Build(&zone, "main() { return; }"));
  EXPECT_STREQ(
      "main(){return 42;}",
      Build(&zone, "main() { return 42; }"));
  EXPECT_STREQ(
      "main(){return 42;return 42;}",
      Build(&zone, "main() { return 42; return 42; }"));

  EXPECT_STREQ(
      "main(){return x;}",
      Build(&zone, "main() { return x; }"));
  EXPECT_STREQ(
      "main(){return x;return y;}",
      Build(&zone, "main() { return x; return y; }"));
  EXPECT_STREQ(
      "main(){return x;return x;}",
      Build(&zone, "main() { return x; return x; }"));

  EXPECT_STREQ(
      "main(){return x.y;}",
      Build(&zone, "main() { return x.y; }"));
  EXPECT_STREQ(
      "main(){return x.y.z;}",
      Build(&zone, "main() { return x.y.z; }"));

  EXPECT_STREQ(
      "main(){return x.y();}",
      Build(&zone, "main() { return x.y(); }"));
  EXPECT_STREQ(
      "main(){return x.y(1);}",
      Build(&zone, "main() { return x.y(1); }"));
  EXPECT_STREQ(
      "main(){return x.y(1,2);}",
      Build(&zone, "main() { return x.y(1,2); }"));

  EXPECT_STREQ(
      "main(){return x.y()();}",
      Build(&zone, "main() { return x.y()(); }"));
  EXPECT_STREQ(
      "main(){return x.y(1)(2);}",
      Build(&zone, "main() { return x.y(1)(2); }"));

  EXPECT_STREQ(
      "main(){if(2)x.y;}",
      Build(&zone, "main() { if (2) x.y; }"));
  EXPECT_STREQ(
      "main(){if(2)x.y;else y.x;}",
      Build(&zone, "main() { if (2) x.y; else y.x;}"));
  EXPECT_STREQ(
      "x()=>$0;",
      Build(&zone, "x() => $0;"));
  EXPECT_STREQ(
      "x()=>$0;",
      Build(&zone, "@a.b.c('x') x() => $0;"));

  EXPECT_STREQ(
      "x(y)=>y;",
      Build(&zone, "x(final y) => y;"));

  EXPECT_STREQ(
      "x()=>const Symbol('dynamic');",
      Build(&zone, "x() => #dynamic;"));
}

TEST_CASE(Canonicalization) {
  Zone zone;
  Builder builder(&zone);
  EXPECT_STREQ("+", builder.Canonicalize("+")->value());
}

TEST_CASE(SimpleClass) {
  Zone zone;

  EXPECT_STREQ(
    "class X {\n"
    "}",
    Build(&zone, "class X { }"));

  EXPECT_STREQ(
    "abstract class X {\n"
    "}",
    Build(&zone, "abstract class X { }"));

  EXPECT_STREQ(
    "class X {\n"
    "foo(){return 42;}\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  foo() { return 42; }\n"
      "}"));

  EXPECT_STREQ(
    "class X {\n"
    "foo(){return 42;}\n"
    "bar(){return (1+2);}\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  foo() { return 42; }\n"
      "  bar() { return 1 + 2; }\n"
      "}"));

  EXPECT_STREQ(
    "class X {\n"
    "X():x=42{}\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  X() : x = 42 { }\n"
      "}"));

  EXPECT_STREQ(
    "class X {\n"
    "factory X(){}\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  factory X() { }\n"
      "}"));
  EXPECT_STREQ(
    "class X {\n"
    "factory X.y()=List.from;\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  factory X.y() = List<String>.from;\n"
      "}"));

  EXPECT_STREQ(
    "class X {\n"
    "var x=42;\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  var x = 42;\n"
      "}"));
  EXPECT_STREQ(
    "class X {\n"
    "var x=42;\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  int x = 42;\n"
      "}"));
  EXPECT_STREQ(
    "class X extends Object {\n"
    "}",
    Build(&zone,
      "class X extends Object {}"));
  EXPECT_STREQ(
    "class X implements Y,Z{\n"
    "}",
    Build(&zone,
      "class X implements Y, Z {}"));
  EXPECT_STREQ(
    "class X extends a.b implements c.d{\n"
    "}",
    Build(&zone,
      "class X extends a.b implements c.d {}"));
  EXPECT_STREQ(
    "class X extends a.b with c.d,e.f implements g.h{\n"
    "}",
    Build(&zone,
      "class X extends a.b with c.d, e.f implements g.h {}"));
  EXPECT_STREQ(
    "class X extends a.b with c.d,e.f implements g.h{\n"
    "}",
    Build(&zone,
      "class X = a.b with c.d, e.f implements g.h;"));
  EXPECT_STREQ(
    "class X {\n"
    "X.y(){}\n"
    "}",
    Build(&zone,
      "class X {\n"
      "  X.y() { }\n"
      "}"));
  EXPECT_STREQ(
    "class X {\n"
    "static var x;\n"
    "}",
    Build(&zone,
      "class X {\n"
      "static var x;\n"
      "}"));
}

TEST_CASE(Imports) {
  Zone zone;
  EXPECT_STREQ(
    "import 'x.dart';",
    Build(&zone, "import 'x.dart';"));
  EXPECT_STREQ(
    "import 'x.dart' as x;",
    Build(&zone, "import 'x.dart' as x;"));
  EXPECT_STREQ(
    "import 'x.dart';",
    Build(&zone, "import 'x.dart' show x hide y;"));
  EXPECT_STREQ(
    "part 'x.dart';",
    Build(&zone, "part 'x.dart';"));
  EXPECT_STREQ(
    "export 'x.dart';",
    Build(&zone, "export 'x.dart';"));
  EXPECT_STREQ(
    "export 'x.dart';",
    Build(&zone, "export 'x.dart' show x hide y;"));
}

TEST_CASE(PartOf) {
  Zone zone;
  EXPECT_STREQ(
    "part of x;\ny(){}",
    Build(&zone, "part of x; y() {}"));
  EXPECT_STREQ(
    "part of x.y.z;",
    Build(&zone, "part of x.y.z;"));
}

TEST_CASE(MethodDeclarations) {
  Zone zone;
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "x() { }"));
  EXPECT_STREQ(
      "x(a){}",
      Build(&zone, "x(a) { }"));
  EXPECT_STREQ(
      "x(a,b){}",
      Build(&zone, "x(a, b) { }"));
  EXPECT_STREQ(
      "x(){y(){}}",
      Build(&zone, "x() { void y() {} }"));
  EXPECT_STREQ(
      "x(){y()=>0;}",
      Build(&zone, "x() { y() => 0; }"));
  EXPECT_STREQ(
      "x(){y()=>0;}",
      Build(&zone, "x() { y() => 0; }"));
  EXPECT_STREQ(
      "x({x:5}){}",
      Build(&zone, "x({x: 5}) {}"));
  EXPECT_STREQ(
      "x([x=5]){}",
      Build(&zone, "x([x = 5]) {}"));
  EXPECT_STREQ(
      "x(a,{b:5,c},[d=4,e]){}",
      Build(&zone, "x(a, {b: 5, c}, [d = 4, e]) {}"));
  EXPECT_STREQ(
      "x(a,{b},[c]){}",
      Build(&zone, "x(a(), {b()}, [c()]) {}"));
}

TEST_CASE(VariableDeclaration) {
  Zone zone;
  EXPECT_STREQ(
      "x(){var y;}",
      Build(&zone, "x() { var y; }"));
  EXPECT_STREQ(
      "x(){var y=42;}",
      Build(&zone, "x() { var y = 42; }"));
}

TEST_CASE(GetAndSet) {
  Zone zone;
  EXPECT_STREQ(
      "get x=>4;",
      Build(&zone, "int get x => 4;"));
  EXPECT_STREQ(
      "get x{}",
      Build(&zone, "get x {}"));
  EXPECT_STREQ(
      "set x(y){}",
      Build(&zone, "set x(y) {}"));
}

TEST_CASE(For) {
  Zone zone;
  EXPECT_STREQ(
      "x(){for(var i=0;(i<4);i+=1){}}",
      Build(&zone, "x() { for (var i = 0; i < 4; i += 1) { } }"));
  EXPECT_STREQ(
      "x(){var i=0;for(;(i<4);i+=1){}}",
      Build(&zone, "x() { int i = 0; for (; i < 4; i += 1) { } }"));
  EXPECT_STREQ(
      "x(){var i=0;for(;;(i++),(i++)){}}",
      Build(&zone, "x() { int i = 0; for (;; i++,i++) { } }"));
  EXPECT_STREQ(
      "x(){for(;;)break;}",
      Build(&zone, "x() { for (;;) break; }"));
}

TEST_CASE(ForIn) {
  Zone zone;
  EXPECT_STREQ(
      "x(){for(var i in list){}}",
      Build(&zone, "x() { for (var i in list) { } }"));
  EXPECT_STREQ(
      "x(){for(i in list){}}",
      Build(&zone, "x() { for (i in list) { } }"));
  EXPECT_STREQ(
      "x(){for(final i in list){}}",
      Build(&zone, "x() { for (final i in list) { } }"));
  EXPECT_STREQ(
      "x(){for(var i in list){}}",
      Build(&zone, "x() { for (Map<String, List<int>> i in list) { } }"));
}

TEST_CASE(While) {
  Zone zone;
  EXPECT_STREQ(
      "x(){while(1){2;}}",
      Build(&zone, "x() { while(1) { 2; } }"));
}

TEST_CASE(DoWhile) {
  Zone zone;
  EXPECT_STREQ(
      "x(){do{2;}while(1);}",
      Build(&zone, "x() { do { 2; } while (1); }"));
}

TEST_CASE(Assign) {
  Zone zone;
  EXPECT_STREQ(
      "x(){1=2;}",
      Build(&zone, "x() { 1 = 2; }"));
  EXPECT_STREQ(
      "x(){1+=2;}",
      Build(&zone, "x() { 1 += 2; }"));
  EXPECT_STREQ(
      "x(){1-=2;}",
      Build(&zone, "x() { 1 -= 2; }"));
  EXPECT_STREQ(
      "x(){1<<=2;}",
      Build(&zone, "x() { 1 <<= 2; }"));
  EXPECT_STREQ(
      "x(){1>>=2;}",
      Build(&zone, "x() { 1 >>= 2; }"));
}

TEST_CASE(Binary) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return (2+2);}",
      Build(&zone, "x() { return 2 + 2; }"));
  EXPECT_STREQ(
      "x(){return (1+(2*3));}",
      Build(&zone, "x() { return 1 + 2 * 3; }"));
  EXPECT_STREQ(
      "x(){return ((1<<2)>>3);}",
      Build(&zone, "x() { return 1 << 2 >> 3; }"));
  EXPECT_STREQ(
      "x(){return (1<=3);}",
      Build(&zone, "x() { return 1 <= 3; }"));
  EXPECT_STREQ(
      "x(){return (1>=3);}",
      Build(&zone, "x() { return 1 >= 3; }"));
}

TEST_CASE(Index) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return null[true];}",
      Build(&zone, "x() { return null[true]; }"));
}

TEST_CASE(Conditional) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return true?1:2;}",
      Build(&zone, "x() { return true ? 1 : 2; }"));
}

TEST_CASE(New) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return new Object(1);}",
      Build(&zone, "x() { return new Object(1); }"));
  EXPECT_STREQ(
      "x(){return const Object(1);}",
      Build(&zone, "x() { return const Object(1); }"));
  EXPECT_STREQ(
      "x(){return new Map();}",
      Build(&zone, "x() { return new Map<String, int>(); }"));
  EXPECT_STREQ(
      "x(y){return new List.from(y);}",
      Build(&zone, "x(y) { return new List<String>.from(y); }"));
}

TEST_CASE(Invoke) {
  Zone zone;
  EXPECT_STREQ(
      "y(){x(5);}",
      Build(&zone, "y(){ x(5); }"));
  EXPECT_STREQ(
      "y(){x(a:5);}",
      Build(&zone, "y(){ x(a: 5); }"));
}

TEST_CASE(Cascade) {
  Zone zone;
  EXPECT_STREQ(
      "x(y){return y..i=4;}",
      Build(&zone, "x(y) { return y..i = 4; }"));
  EXPECT_STREQ(
      "x(y){return y..set=4;}",
      Build(&zone, "x(y) { return y..set = 4; }"));
  EXPECT_STREQ(
      "x(y){return y..[0]=3;}",
      Build(&zone, "x(y) { return y..[0] = 3; }"));
  EXPECT_STREQ(
      "x(y){return y..x.x=3;}",
      Build(&zone, "x(y) { return y..x.x = 3; }"));
  EXPECT_STREQ(
      "x(y){return y..[0]=y..x=5;}",
      Build(&zone, "x(y) { return y..[0] = y..x = 5; }"));
}

TEST_CASE(StringInterpolation) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return 'f ${y} z';}",
      Build(&zone, "x() { return 'f $y z'; }"));
  EXPECT_STREQ(
      "x(){return 'f ${(3+4)} z';}",
      Build(&zone, "x() { return 'f ${3 + 4} z'; }"));
  EXPECT_STREQ(
      "x(){return '${y} ';}",
      Build(&zone, "x() { return '$y'' '; }"));
  EXPECT_STREQ(
      "x(){return '${y}${x}';}",
      Build(&zone, "x() { return '$y''$x'; }"));
  EXPECT_STREQ(
      "x(){return ' ${y}';}",
      Build(&zone, "x() { return ' ''${y}'; }"));
  EXPECT_STREQ(
      "x(){return '${''}';}",
      Build(&zone, "x() { return '${''}'; }"));
}

TEST_CASE(StringLiteral) {
  Zone zone;
  EXPECT_STREQ(
      "x(){'  ';}",
      Build(&zone, "x() { ' '' '; }"));
  EXPECT_STREQ(
      "x(){'xy';}",
      Build(&zone, "x() { 'x''y'; }"));
}

TEST_CASE(FunctionExpression) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return ()=>4;}",
      Build(&zone, "x() { return () => 4; }"));
}

TEST_CASE(SimpleLiterals) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return this;}",
      Build(&zone, "x() { return this; }"));
  EXPECT_STREQ(
      "x(){return null;}",
      Build(&zone, "x() { return null; }"));
  EXPECT_STREQ(
      "x(){return true;}",
      Build(&zone, "x() { return true; }"));
  EXPECT_STREQ(
      "x(){return false;}",
      Build(&zone, "x() { return false; }"));
}

TEST_CASE(LiteralList) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return [1,2,3];}",
      Build(&zone, "x() { return [1, 2, 3]; }"));
  EXPECT_STREQ(
      "x(){return [];}",
      Build(&zone, "x() { return []; }"));
  EXPECT_STREQ(
      "x(){return ['hej'];}",
      Build(&zone, "x() { return ['hej',]; }"));
}

TEST_CASE(LiteralMap) {
  Zone zone;
  EXPECT_STREQ(
      "x(){return {'x':1,'y':'a'};}",
      Build(&zone, "x() { return {'x': 1, 'y': 'a'}; }"));
  EXPECT_STREQ(
      "x(y){return {y:y};}",
      Build(&zone, "x(y) { return {y: y}; }"));
  EXPECT_STREQ(
      "x(){return {};}",
      Build(&zone, "x() { return <String, String>{}; }"));
  EXPECT_STREQ(
      "x(){return {'a':y};}",
      Build(&zone, "x() { return {'a': y,}; }"));
  EXPECT_STREQ(
      "x(){return {};}",
      Build(&zone, "x() { return const <String, String>{}; }"));
}

TEST_CASE(SkipReturnTypes) {
  Zone zone;
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "void x() { }"));
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "dynamic x() { }"));
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "int x() { }"));
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "List<int> x() { }"));
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "Map<List<int>, String> x() { }"));
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "Map<List<int>, List<List<dynamic>>> x() { }"));
  EXPECT_STREQ(
      "get(){}",
      Build(&zone, "List get() { }"));
  EXPECT_STREQ(
      "x(){}",
      Build(&zone, "a.b x() { }"));
}

TEST_CASE(Typedef) {
  Zone zone;
  EXPECT_STREQ(
      "typedef x(y);",
      Build(&zone, "typedef void x(List<int> y);"));
  EXPECT_STREQ(
      "typedef x(y);",
      Build(&zone, "typedef void x<X>(List<X> y);"));
}

TEST_CASE(Is) {
  Zone zone;
  EXPECT_STREQ(
      "x(y)=>y is Object;",
      Build(&zone, "x(y)=>y is Object;"));
  EXPECT_STREQ(
      "x(y)=>y is! Object;",
      Build(&zone, "x(y)=>y is! Object;"));
  EXPECT_STREQ(
      "x(y)=>y is! Map;",
      Build(&zone, "x(y)=>y is! Map<String, int>;"));
}

TEST_CASE(As) {
  Zone zone;
  EXPECT_STREQ(
      "x(y)=>y as Object;",
      Build(&zone, "x(y)=>y as Object;"));
  EXPECT_STREQ(
      "x(y)=>y as Map;",
      Build(&zone, "x(y)=>y as Map<String, int>;"));
}

TEST_CASE(Break) {
  Zone zone;
  EXPECT_STREQ(
      "x(y){while(true)break;}",
      Build(&zone, "x(y) { while (true) break; }"));
  EXPECT_STREQ(
      "x(y){X:while(true)break X;}",
      Build(&zone, "x(y) { X: while (true) break X; }"));
}

TEST_CASE(Continue) {
  Zone zone;
  EXPECT_STREQ(
      "x(y){while(true)continue;}",
      Build(&zone, "x(y) { while (true) continue; }"));
  EXPECT_STREQ(
      "x(y){X:while(true)continue X;}",
      Build(&zone, "x(y) { X: while (true) continue X; }"));
}

TEST_CASE(Assert) {
  Zone zone;
  EXPECT_STREQ(
      "x(){assert(true);}",
      Build(&zone, "x() { assert(true); }"));
}

TEST_CASE(LabelledStatement) {
  Zone zone;
  EXPECT_STREQ(
      "x(){X:while(true){}}",
      Build(&zone, "x() { X: while(true){} }"));
}

TEST_CASE(Switch) {
  Zone zone;
  EXPECT_STREQ(
      "x(y){switch(y){default:break;}}",
      Build(&zone, "x(y) { switch(y) { default: break; }}"));
  EXPECT_STREQ(
      "x(y){switch(y){case 0:break;default:}}",
      Build(&zone, "x(y) { switch(y) { case 0: break; }}"));
}

TEST_CASE(Try) {
  Zone zone;
  EXPECT_STREQ(
      "x(){try{}on int catch(e,s){}finally{}}",
      Build(&zone, "x() { try {} on int catch (e, s){} finally{}}"));
  EXPECT_STREQ(
      "x(){try{}catch(e){}}",
      Build(&zone, "x() { try {} catch (e) {}}"));
  EXPECT_STREQ(
      "x(){try{}on String {}}",
      Build(&zone, "x() { try {} on String {}}"));
  EXPECT_STREQ(
      "x(){try{}finally{}}",
      Build(&zone, "x() { try {} finally {}}"));
  EXPECT_STREQ(
      "x(){try{}catch(e){rethrow;}}",
      Build(&zone, "x() { try {} catch (e) { rethrow; }}"));
}

TEST_CASE(Symbol) {
  Zone zone;
  EXPECT_STREQ(
      "x()=>const Symbol('x.y');",
      Build(&zone, "x() => #x.y;"));
}

TEST_CASE(Initializers) {
  Zone zone;
  EXPECT_STREQ(
      "class A {\nvar x;\nA(y):x=(y){}\n}",
      Build(&zone, "class A { int x; A(y) : x = (y) {} }"));
  EXPECT_STREQ(
      "class A {\nA():super(5);\n}",
      Build(&zone, "class A { A() : super(5); }"));
  EXPECT_STREQ(
      "class A {\nvar x;\nA():this.x=5;\n}",
      Build(&zone, "class A { int x; A() : this.x = 5; }"));
  EXPECT_STREQ(
      "class A {\nA():this._(5);\nA._(x);\n}",
      Build(&zone, "class A { A() : this._(5); A._(x); }"));
}

}  // namespace fletch
