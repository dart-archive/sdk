// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fletchc.test.feature_test;

import 'dart:io' hide
    exitCode,
    stderr,
    stdin,
    stdout;

import 'dart:io' as io;

import 'dart:async' show
    Future,
    Stream,
    StreamIterator;

import 'dart:convert' show
    LineSplitter,
    UTF8,
    Utf8Decoder;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/incremental/scope_information_visitor.dart' show
    ScopeInformationVisitor;

import 'io_compiler_test_case.dart' show
    IoCompilerTestCase,
    IoInputProvider;

import 'compiler_test_case.dart' show
    CompilerTestCase;

import 'package:compiler/src/elements/elements.dart' show
    Element,
    FieldElement,
    FunctionElement,
    LibraryElement;

import 'package:compiler/src/dart2jslib.dart' show
    Compiler;

import 'package:fletchc/incremental/fletchc_incremental.dart' show
    IncrementalCompilationFailed;

import 'package:fletchc/commands.dart' show
    Command,
    MapId;

import 'package:fletchc/commands.dart' as commands_lib;

import 'package:fletchc/session.dart' show
    CommandReader,
    Session;

import 'program_result.dart';

const bool testSessionReset = const bool.fromEnvironment("testSessionReset");

typedef Future NoArgFuture();

const Map<String, EncodedResult> tests = const <String, EncodedResult>{
    // Basic hello-world test.
    "hello_world": const EncodedResult(
        const [
            "main() { print('Hello, ",
            const ["", "Brave New "],
            "World!'); }",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['Hello, World!']),
            const ProgramExpectation(
                const <String>['Hello, Brave New World!']),
        ]),

    // Test that we can manipulate a field from an instance
    // of a class from the end of the field list.
    "instance_field_end": const EncodedResult(
        r"""
==> main.dart.patch <==
class A {
  var x;
<<<<<<<
  var y;
=======
=======
  int y;  // TODO(ahe): We don't add the field unless the tokens change.
>>>>>>>
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new A();
    instance.x = 0;
  } else {
    print('x = ${instance.x}');
  }
}
""",
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>[
                    'instance is null']),
            const ProgramExpectation(
                const <String>[
                    'x = 0']),
            const ProgramExpectation(
                const <String>[
                    'x = 0']),
        ]),

    // Test that we can manipulate a field from an instance
    // of a class from the middle of the field list.
    "instance_field_middle": const EncodedResult(
        r"""
==> main.dart.patch <==
class A {
  var x;
<<<<<<<
  var y;
=======
=======
  int y;  // TODO(ahe): We don't add the field unless the tokens change.
>>>>>>>
  var z;
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new A();
    instance.x = 0;
    instance.y = 1;
    instance.z = 2;
  } else {
    print('x = ${instance.x}');
    if (instance.x == 3) {
      print('y = ${instance.y}');
      print('z = ${instance.z}');
    }
    instance.x = 3;
  }
}
""",
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>[
                    'instance is null']),
            const ProgramExpectation(
                const <String>[
                    'x = 0']),
            const ProgramExpectation(
                const <String>[
                    'x = 3', 'y = null', 'z = 2']),
        ]),

    // Test that schema changes affect subclasses correctly.
    "subclass_schema_1": const EncodedResult(
        r"""
==> main.dart.patch <==
class A {
  var x;
<<<<<<<
  var y;
=======
=======
  int y;  // // TODO(ahe): We don't add the field unless the tokens change.
>>>>>>>
}

class B extends A {
  var z;
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new B();
    instance.x = 0;
    instance.y = 1;
    instance.z = 2;
  } else {
    print('x = ${instance.x}');
    if (instance.x == 3) {
      print('y = ${instance.y}');
      print('z = ${instance.z}');
    }
    instance.x = 3;
  }
}
""",
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>[
                    'instance is null']),
            const ProgramExpectation(
                const <String>[
                    'x = 0']),
            const ProgramExpectation(
                const <String>[
                    'x = 3', 'y = null', 'z = 2']),
        ]),

    // Test that schema changes affect subclasses of subclasses correctly.
    "subclass_schema_2": const EncodedResult(
        r"""
==> main.dart.patch <==
class A {
  var x;
<<<<<<<
  var y;
=======
=======
 int y;  // // TODO(ahe): We don't add the field unless the tokens change.
>>>>>>>
}

class B extends A {
}

class C extends B {
  var z;
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
    instance.x = 0;
    instance.y = 1;
    instance.z = 2;
  } else {
    print('x = ${instance.x}');
    if (instance.x == 3) {
      print('y = ${instance.y}');
      print('z = ${instance.z}');
    }
    instance.x = 3;
  }
}
""",
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>[
                    'instance is null']),
            const ProgramExpectation(
                const <String>[
                    'x = 0']),
            const ProgramExpectation(
                const <String>[
                    'x = 3', 'y = null', 'z = 2']),
        ]),

    // Test that schema changes work in the presence of fields in
    // the superclass.
    "super_schema": const EncodedResult(
        r"""
==> main.dart.patch <==
class A {
  var x;
}

class B extends A {
<<<<<<<
  var y;
=======
=======
  int y;  // // TODO(ahe): We don't add the field unless the tokens change.
>>>>>>>
  var z;
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new B();
    instance.x = 0;
    instance.y = 1;
    instance.z = 2;
  } else {
    print('x = ${instance.x}');
    if (instance.x == 3) {
      print('y = ${instance.y}');
      print('z = ${instance.z}');
    }
    instance.x = 3;
  }
}
""",
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>[
                    'instance is null']),
            const ProgramExpectation(
                const <String>[
                    'x = 0']),
            const ProgramExpectation(
                const <String>[
                    'x = 3', 'y = null', 'z = 2']),
        ]),

    "add_instance_field": const EncodedResult(
        r"""
==> main.dart.patch <==
// Test adding a field to a class works.

class A {
<<<<<<<
=======
  var x;
>>>>>>>
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new A();
  }
  try {
    instance.x = 'v2';
  } catch(e) {
    print('setter threw');
  }
  try {
    print(instance.x);
  } catch (e) {
    print('getter threw');
  }
}
""",
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>[
                    'instance is null', 'setter threw', 'getter threw']),
            const ProgramExpectation(
                const <String>[
                    'v2']),
        ]),

    "remove_instance_field": const EncodedResult(
        r"""
==> main.dart.patch <==
// Test removing a field from a class works.

class A {
<<<<<<<
  var x;
=======
>>>>>>>
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new A();
  }
  try {
    instance.x = 'v1';
  } catch(e) {
    print('setter threw');
  }
  try {
    print(instance.x);
  } catch (e) {
    print('getter threw');
  }
}
""",
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>['setter threw', 'getter threw']),
        ]),

    // Test that the test framework handles more than one update.
    "two_updates": const EncodedResult(
        const [
            "main() { print('",
            const [
                "Hello darkness, my old friend",
                "I\\'ve come to talk with you again",
                "Because a vision softly creeping",
            ],
            "'); }",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['Hello darkness, my old friend']),
            const ProgramExpectation(
                const <String>['I\'ve come to talk with you again']),
            const ProgramExpectation(
                const <String>['Because a vision softly creeping']),
        ]),

    // Test that that isolate support works.
    "main_args": const EncodedResult(
        const [
            "main(arguments) { print(",
            const [
                "'Hello, Isolated World!'",
                "arguments"
            ],
            "); }",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['Hello, Isolated World!']),
            const ProgramExpectation(
                const <String>['[]']),
        ]),

    "stored_closure": const EncodedResult(
        const [
            r"""
// Test that a stored closure changes behavior when updated.

var closure;

foo(a, [b = 'b']) {
""",
            const [
                r"""
  print('$a $b');
""",
                r"""
  print('$b $a');
""",
            ],
            r"""
}

main() {
  if (closure == null) {
    print('[closure] is null.');
    closure = foo;
  }
  closure('a');
  closure('a', 'c');
}
"""],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['[closure] is null.', 'a b', 'a c']),
            const ProgramExpectation(
                const <String>['b a', 'c a']),
        ]),

    "modify_static_method": const EncodedResult(
        const [
            """
// Test modifying a static method works.

class C {
  static m() {
""",
            const [
                r"""
  print('v1');
""",
                r"""
  print('v2');
""",
            ],
            """
  }
}
main() {
  C.m();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "modify_instance_method": const EncodedResult(
        const [
            """
// Test modifying an instance method works.

class C {
  m() {
""",
            const [
                r"""
  print('v1');
""",
                r"""
  print('v2');
""",
            ],
            """
  }
}
var instance;
main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
  instance.m();
}
""",

        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>[
                    'instance is null', // TODO(ahe): Remove this line.
                    'v2']),
        ]),

    "stored_instance_tearoff": const EncodedResult(
        const [
            """
// Test that a stored instance tearoff changes behavior when updated.

class C {
  m() {
""",
            const [
                r"""
  print('v1');
""",
                r"""
  print('v2');
""",
            ],
                """
  }
}
var closure;
main() {
  if (closure == null) {
    print('closure is null');
    closure = new C().m;
  }
  closure();
}
""",

        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['closure is null', 'v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "remove_instance_method": const EncodedResult(
        const [
            """
// Test that deleting an instance method works.

class C {
""",
            const [
                """
  m() {
    print('v1');
  }
""",
                """
""",
            ],
            """
}
var instance;
main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
  try {
    instance.m();
  } catch (e) {
    print('threw');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>['threw'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "remove_instance_method_super_access": const EncodedResult(
        const [
            """
// Test that deleting an instance method works, even when accessed through
// super.

class A {
  m() {
    print('v2');
  }
}
class B extends A {
""",
            const [
                """
  m() {
    print('v1');
  }
""",
                """
""",
            ],
            """
}
class C extends B {
  m() {
    super.m();
  }
}
var instance;
main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
  instance.m();
}
""",

        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>['v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "remove_top_level_method": const EncodedResult(
        const [
            """
// Test that deleting a top-level method works.

""",
            const [
                """
toplevel() {
  print('v1');
}
""",
                """
""",
            ],
            """
class C {
  m() {
    try {
      toplevel();
    } catch (e) {
      print('threw');
    }
  }
}
var instance;
main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
  instance.m();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>['threw'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "remove_static_method": const EncodedResult(
        const [
            """
// Test that deleting a static method works.

class B {
""",
            const [
                """
  static staticMethod() {
    print('v1');
  }
""",
                """
""",
            ],
                """
}
class C {
  m() {
    try {
      B.staticMethod();
    } catch (e) {
      print('threw');
    }
    try {
      // Ensure that noSuchMethod support is compiled. This test is not about
      // adding new classes.
      B.missingMethod();
      print('bad');
    } catch (e) {
    }
  }
}
var instance;
main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
  instance.m();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>['threw'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "newly_instantiated_class": const EncodedResult(
        const [
            """
// Test that a newly instantiated class is handled.

class A {
  m() {
    print('Called A.m');
  }
}

class B {
  m() {
    print('Called B.m');
  }
}

var instance;
main() {
  if (instance == null) {
    print('instance is null');
    instance = new A();
""",
            const [
                """
""",
                """
  } else {
    instance = new B();
""",
            ],
            """
  }
  instance.m();
}
""",

        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'Called A.m']),
            const ProgramExpectation(
                const <String>[
                    'instance is null', // TODO(ahe): Remove this.
                    'Called A.m', // TODO(ahe): Should be B.m.
                  ]),
        ]),

    "source_maps_no_throw": const EncodedResult(
        const [
            """
// Test that source maps don't throw exceptions.

main() {
  print('a');
""",
            const [
                """
""",
                """
  print('b');
  print('c');
""",
            ],
            """
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['a']),
            const ProgramExpectation(
                const <String>['a', 'b', 'c']),
        ]),

    "newly_instantiated_class_X": const EncodedResult(
        // TODO(ahe): How is this different from the other test with same
        // comment.
        const [
            r"""
// Test that a newly instantiated class is handled.

class A {
  get name => 'A.m';

  m() {
    print('Called $name');
  }
}

class B extends A {
  get name => 'B.m';
}

var instance;
main() {
  if (instance == null) {
    print('instance is null');
    instance = new A();
""",
            const [
                r"""
""",
                r"""
  } else {
    instance = new B();
""",
            ],
            r"""
  }
  instance.m();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'Called A.m']),
            const ProgramExpectation(
                const <String>['instance is null', 'Called A.m']),
            // TODO(ahe): Should be:
            // const ProgramExpectation(
            //     const <String>['Called B.m']),
        ]),

    "newly_instantiated_class_with_fields": const EncodedResult(
        const [
            r"""
// Test that fields of a newly instantiated class are handled.

class A {
  var x;
  A(this.x);
}
var instance;
foo() {
  if (instance != null) {
    print(instance.x);
  } else {
    print('v1');
  }
}
main() {
""",
            const [
                r"""
""",
                r"""
  instance = new A('v2');
""",
            ],
            r"""
  foo();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "add_top_level_method": const EncodedResult(
        const [
            r"""
// Test that top-level functions can be added.

""",
            const [
                "",
                r"""
foo() {
  print('v2');
}
""",
            ],
            r"""
main() {
  try {
    foo();
  } catch(e) {
    print('threw');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['threw']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "add_static_method": const EncodedResult(
        const [
            r"""
// Test that static methods can be added.

class C {
""",
            const [
                "",
                r"""
  static foo() {
    print('v2');
  }
""",
            ],
            r"""
}

main() {
  try {
    C.foo();
  } catch(e) {
    print('threw');
  }
}
""",

        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['threw']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "add_instance_method": const EncodedResult(
        const [
            r"""
// Test that instance methods can be added.

class C {
""",
            const [
                "",
                r"""
  foo() {
    print('v2');
  }
""",
            ],
            r"""
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }

  try {
    instance.foo();
  } catch(e) {
    print('threw');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'threw']),
            const ProgramExpectation(
                const <String>[
                    'instance is null', // TODO(ahe): Remove this.
                    'v2']),
        ]),

    "signature_change_top_level_method": const EncodedResult(
        const [
            r"""
// Test that top-level functions can have signature changed.

""",
            const [
                r"""
foo() {
  print('v1');
""",
                r"""
void foo() {
  print('v2');
""",
            ],
            r"""
}

main() {
  foo();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "signature_change_static_method": const EncodedResult(
        const [
            r"""
// Test that static methods can have signature changed.

class C {
""",
            const [
                r"""
  static foo() {
    print('v1');
""",
                r"""
  static void foo() {
    print('v2');
""",
            ],
            r"""
  }
}

main() {
  C.foo();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "signature_change_instance_method": const EncodedResult(
        const [
            r"""
// Test that instance methods can have signature changed.

class C {
""",
            const [
                r"""
  foo() {
    print('v1');
""",
                r"""
  void foo() {
    print('v2');
""",
            ],
            r"""
  }
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }

  instance.foo();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>['v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "add_class": const EncodedResult(
        const [
            r"""
// Test that adding a class is supported.

""",
            const [
                "",
                r"""
class C {
  void foo() {
    print('v2');
  }
}
""",
            ],
            r"""
main() {
""",
            const [
                r"""
  print('v1');
""",
                r"""
  new C().foo();
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "remove_class": const EncodedResult(
        const [
            r"""
// Test that removing a class is supported, using constructor.

""",
            const [
                r"""
class C {
}
""",
                ""
            ],
            r"""
main() {
  try {
    new C();
    print('v1');
  } catch (e) {
    print('v2');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "remove_class_with_static_method": const EncodedResult(
        const [
            r"""
// Test that removing a class is supported, using a static method.

""",
            const [
                r"""
class C {
  static m() {
    print('v1');
  }
}
""",
                "",
            ],
            r"""
main() {
  try {
    C.m();
  } catch (e) {
    print('v2');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "change_supertype": const EncodedResult(
        const [
            r"""
// Test that changing the supertype of a class works.

class A {
  m() {
    print('v2');
  }
}
class B extends A {
  m() {
    print('v1');
  }
}
""",
            const [
                r"""
class C extends B {
""",
                r"""
class C extends A {
""",
            ],
            r"""
  m() {
    super.m();
  }
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
  instance.m();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>[
                    'instance is null', // TODO(ahe): Remove this.
                    'v2']),
        ]),

    "call_named_arguments_1": const EncodedResult(
        const [
            r"""
// Test that named arguments can be called.

class C {
  foo({a, named: 'v1', x}) {
    print(named);
  }
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
""",
            const [
                r"""
  instance.foo();
""",
                r"""
  instance.foo(named: 'v2');
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>[
                    'instance is null', // TODO(ahe): Remove this.
                    'v2']),
        ]),

    "call_named_arguments_2": const EncodedResult(
        const [
            r"""
// Test that named arguments can be called.

class C {
  foo({a, named: 'v2', x}) {
    print(named);
  }
}

var instance;

main() {
  if (instance == null) {
    print('instance is null');
    instance = new C();
  }
""",
            const [
                r"""
  instance.foo(named: 'v1');
""",
                r"""
  instance.foo();
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['instance is null', 'v1']),
            const ProgramExpectation(
                const <String>[
                    'instance is null', // TODO(ahe): Remove this.
                    'v2']),
        ]),

    "call_instance_tear_off_named": const EncodedResult(
        const [
            r"""
// Test that an instance tear-off with named parameters can be called.

class C {
  foo({a, named: 'v1', x}) {
    print(named);
  }
}

var closure;

main() {
  if (closure == null) {
    print('closure is null');
    closure = new C().foo;
  }
""",
            const [
                r"""
  closure();
""",
                r"""
  closure(named: 'v2');
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['closure is null', 'v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "lazy_static": const EncodedResult(
        const [
            r"""
// Test that a lazy static is supported.

var normal;

""",
            const [
                r"""
foo() {
  print(normal);
}
""",
                r"""
var lazy = bar();

foo() {
  print(lazy);
}

bar() {
  print('v2');
  return 'lazy';
}

""",
            ],
            r"""
main() {
  if (normal == null) {
    normal = 'v1';
  } else {
    normal = '';
  }
  foo();
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2', 'lazy']),
        ]),

    "super_classes_of_directly_instantiated": const EncodedResult(
        const [
            r"""
// Test that superclasses of directly instantiated classes are also emitted.
class A {
}

class B extends A {
}

main() {
""",
            const [
                r"""
  print('v1');
""",
                r"""
  new B();
  print('v2');
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "interceptor_classes": const EncodedResult(
        const [
            r"""
// Test that interceptor classes are handled correctly.

main() {
""",
            const [
                r"""
  print('v1');
""",
                r"""
  ['v2'].forEach(print);
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "newly_instantiated_superclasses_two_updates": const EncodedResult(
        const [
            r"""
// Test that newly instantiated superclasses are handled correctly when there
// is more than one change.

class A {
  foo() {
    print('Called foo');
  }

  bar() {
    print('Called bar');
  }
}

class B extends A {
}

main() {
""",
            const [
                r"""
  new B().foo();
""",
                r"""
  new B().foo();
""",
            r"""
  new A().bar();
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['Called foo']),
            const ProgramExpectation(
                const <String>['Called foo']),
            const ProgramExpectation(
                const <String>['Called bar']),
        ]),

    "newly_instantiated_subclases_two_updates": const EncodedResult(
        const [
            r"""
// Test that newly instantiated subclasses are handled correctly when there is
// more than one change.

class A {
  foo() {
    print('Called foo');
  }

  bar() {
    print('Called bar');
  }
}

class B extends A {
}

main() {
""",
            const [
                r"""
  new A().foo();
""",
                r"""
  new A().foo();
""",
            r"""
  new B().bar();
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['Called foo']),
            const ProgramExpectation(
                const <String>['Called foo']),
            const ProgramExpectation(
                const <String>['Called bar']),
        ]),

    "constants": const EncodedResult(
        const [
            r"""
// Test that constants are handled correctly.

class C {
  final String value;
  const C(this.value);
}

main() {
""",
            const [
                r"""
  print(const C('v1').value);
""",
                r"""
  print(const C('v2').value);
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['v1']),
            const ProgramExpectation(
                const <String>['v2']),
        ]),

    "add_compound_instance_field": const EncodedResult(
        const [
            r"""
// Test that an instance field can be added to a compound declaration.

class C {
""",
            const [
                r"""
  int x;
""",
                r"""
  int x, y;
""",
            ],
                r"""
}

var instance;

main() {
  if (instance == null) {
    print('[instance] is null');
    instance = new C();
    instance.x = 'v1';
  } else {
    instance.y = 'v2';
  }
  try {
    print(instance.x);
  } catch (e) {
    print('[instance.x] threw');
  }
  try {
    print(instance.y);
  } catch (e) {
    print('[instance.y] threw');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>[
                    '[instance] is null', 'v1', '[instance.y] threw']),
            const ProgramExpectation(
                const <String>['v1', 'v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "remove_compound_instance_field": const EncodedResult(
        const [
            r"""
// Test that an instance field can be removed from a compound declaration.

class C {
""",
            const [
                r"""
  int x, y;
""",
                r"""
  int x;
""",
            ],
                r"""
}

var instance;

main() {
  if (instance == null) {
    print('[instance] is null');
    instance = new C();
    instance.x = 'v1';
    instance.y = 'v2';
  }
  try {
    print(instance.x);
  } catch (e) {
    print('[instance.x] threw');
  }
  try {
    print(instance.y);
  } catch (e) {
    print('[instance.y] threw');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['[instance] is null', 'v1', 'v2']),
            const ProgramExpectation(
                const <String>['v1', '[instance.y] threw'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "static_field_to_instance_field": const EncodedResult(
        const [
            r"""
// Test that a static field can be made an instance field.

class C {
""",

            const [
                r"""
  static int x;
""",
                r"""
  int x;
""",
            ],
                r"""
}

var instance;

main() {
  if (instance == null) {
    print('[instance] is null');
    instance = new C();
    C.x = 'v1';
  } else {
    instance.x = 'v2';
  }
  try {
    print(C.x);
  } catch (e) {
    print('[C.x] threw');
  }
  try {
    print(instance.x);
  } catch (e) {
    print('[instance.x] threw');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['[instance] is null', 'v1', '[instance.x] threw']),
            const ProgramExpectation(
                const <String>['[C.x] threw', 'v2'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "instance_field_to_static_field": const EncodedResult(
        const [
            r"""
// Test that instance field can be made static.

class C {
""",
            const [
                r"""
  int x;
""",
                r"""
  static int x;
""",
            ],
            r"""
}

var instance;

main() {
  if (instance == null) {
    print('[instance] is null');
    instance = new C();
    instance.x = 'v1';
  } else {
    C.x = 'v2';
  }
  try {
    print(C.x);
  } catch (e) {
    print('[C.x] threw');
  }
  try {
    print(instance.x);
  } catch (e) {
    print('[instance.x] threw');
  }
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['[instance] is null', '[C.x] threw', 'v1']),
            const ProgramExpectation(
                const <String>['v2', '[instance.x] threw'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "compound_constants": const EncodedResult(
        const [
            r"""
// Test compound constants.

class A {
  final value;
  const A(this.value);

  toString() => 'A($value)';
}

class B {
  final value;
  const B(this.value);

  toString() => 'B($value)';
}

main() {
""",
            const [
                r"""
  print(const A('v1'));
  print(const B('v1'));
""",
                r"""
  print(const B(const A('v2')));
  print(const A(const B('v2')));
""",
            ],
            r"""
}
""",
        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['A(v1)', 'B(v1)']),
            const ProgramExpectation(
                const <String>['B(A(v2))', 'A(B(v2))']),
        ]),

    "constants_of_new_classes": const EncodedResult(
        const [
            r"""
// Test constants of new classes.

class A {
  final value;
  const A(this.value);

  toString() => 'A($value)';
}
""",
            const [
                "",
                r"""
class B {
  final value;
  const B(this.value);

  toString() => 'B($value)';
}

""",
            ],
            r"""
main() {
""",

            const [
                r"""
  print(const A('v1'));
""",
                r"""
  print(const A('v2'));
  print(const B('v2'));
  print(const B(const A('v2')));
  print(const A(const B('v2')));
""",
            ],
            r"""
}
""",

        ],
        const <ProgramExpectation>[
            const ProgramExpectation(
                const <String>['A(v1)']),
            const ProgramExpectation(
                const <String>['A(v2)', 'B(v2)', 'B(A(v2))', 'A(B(v2))']),
        ]),

    "change_in_part": const EncodedResult(
        r"""
==> main.dart <==
// Test that a change in a part is handled.
library test.main;

part 'part.dart';


==> part.dart.patch <==
part of test.main;

main() {
<<<<<<<
  print('Hello, World!');
=======
  print('Hello, Brave New World!');
>>>>>>>
}
""",
        const [
            'Hello, World!',
            'Hello, Brave New World!',
        ]),

    "change_library_name": const EncodedResult(
        r"""
==> main.dart.patch <==
// Test that a change in library name is handled.
<<<<<<<
library test.main1;
=======
library test.main2;
>>>>>>>

main() {
  print('Hello, World!');
}
""",
        const [
            'Hello, World!',
            const ProgramExpectation(
                const <String>['Hello, World!'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "add_import": const EncodedResult(
        r"""
==> main.dart.patch <==
// Test that adding an import is handled.
<<<<<<<
=======
import 'dart:core';
>>>>>>>

main() {
  print('Hello, World!');
}
""",
        const [
            'Hello, World!',
            const ProgramExpectation(
                const <String>['Hello, World!'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "add_export": const EncodedResult(
        r"""
==> main.dart.patch <==
// Test that adding an export is handled.
<<<<<<<
=======
export 'dart:core';
>>>>>>>

main() {
  print('Hello, World!');
}
""",
        const [
            'Hello, World!',
            const ProgramExpectation(
                const <String>['Hello, World!'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "add_part": const EncodedResult(
        r"""
==> main.dart.patch <==
// Test that adding a part is handled.
library test.main;

<<<<<<<
=======
part 'part.dart';
>>>>>>>

main() {
  print('Hello, World!');
}


==> part.dart <==
part of test.main
""",
        const [
            'Hello, World!',
            const ProgramExpectation(
                const <String>['Hello, World!'],
                // TODO(ahe): Should not throw.
                compileUpdatesShouldThrow: true),
        ]),

    "multiple_libraries": const EncodedResult(
        r"""
==> main.dart <==
// Test that changes in multiple libraries is handled.
import 'library1.dart' as lib1;
import 'library2.dart' as lib2;

main() {
  lib1.method();
  lib2.method();
}


==> library1.dart.patch <==
library test.library1;

method() {
<<<<<<<
  print('lib1.v1');
=======
  print('lib1.v2');
=======
  print('lib1.v3');
>>>>>>>
}


==> library2.dart.patch <==
library test.library2;

method() {
<<<<<<<
  print('lib2.v1');
=======
  print('lib2.v2');
=======
  print('lib2.v3');
>>>>>>>
}
""",
        const [
            const <String>['lib1.v1', 'lib2.v1'],
            const <String>['lib1.v2', 'lib2.v2'],
            const <String>['lib1.v3', 'lib2.v3'],
        ]),
};

Future<Null> main(List<String> arguments) async {
  var testsToRun;
  if (arguments.isEmpty) {
    int skip = const int.fromEnvironment("skip", defaultValue: 0);
    testCount += skip;
    skippedCount += skip;

    testsToRun = tests.values.skip(skip);
    // TODO(ahe): Remove the following line, as it means only run the
    // first few tests.
    testsToRun = testsToRun.take(8);
  } else {
    testsToRun = arguments.map((String name) => tests[name]);
  }
  for (EncodedResult test in testsToRun) {
    await compileAndRun(test);
  }
  updateSummary();
}

int testCount = 1;

int skippedCount = 0;

int updateFailedCount = 0;

bool verboseStatus = const bool.fromEnvironment("verbose", defaultValue: false);

void updateSummary() {
  print(
      "\n\nTest ${testCount - 1} of ${tests.length} "
      "($skippedCount skipped, $updateFailedCount failed).");
}

compileAndRun(EncodedResult encodedResult) async {
  testCount++;

  updateSummary();
  List<ProgramResult> programs = encodedResult.decode();

  // The first program is compiled "fully". There rest are compiled below
  // as incremental updates to this first program.
  ProgramResult program = programs.first;

  print("Full program #$testCount:");
  print(numberedLines(program.code));

  IoCompilerTestCase test = new IoCompilerTestCase(program.code);
  List<Command> commands = await test.run();

  TestSession session = await runFletchVM(test, commands);

  bool hasStderrOutput = false;
  bool hasExtraStdoutOutput = false;
  int vmExitCode;

  // TODO(ahe): Replace new Future with try/finally when Dart VM bug 23537 is
  // fixed.
  await new Future(() async {
    for (String expected in program.messages) {
      Expect.isTrue(await session.iterator.moveNext());
      Expect.stringEquals(expected, session.iterator.current);
      print("Got expected output: ${session.iterator.current}");
    }

    if (testSessionReset) {
      for (String expected in program.messages) {
        Expect.isTrue(await session.iterator.moveNext());
        Expect.stringEquals(expected, session.iterator.current);
        print("Got expected output: ${session.iterator.current}");
      }
    }

    int version = 2;
    for (ProgramResult program in programs.skip(1)) {
      print("Update:");
      print(numberedLines(program.code));

      IoInputProvider inputProvider =
          test.incrementalCompiler.inputProvider;
      Uri base = test.scriptUri;
      Map<String, String> code = program.code is String
          ? { 'main.dart': program.code }
          : program.code;
      Map<Uri, Uri> uriMap = <Uri, Uri>{};
      for (String name in code.keys) {
        Uri uri = base.resolve('$name?v${version++}');
        inputProvider.cachedSources[uri] = new Future.value(code[name]);
        uriMap[base.resolve(name)] = uri;
      }
      Future future = test.incrementalCompiler.compileUpdates(
          uriMap, logVerbose: logger, logTime: logger);
      bool compileUpdatesThrew = false;
      future = future.catchError((error, trace) {
        String statusMessage;
        Future result;
        compileUpdatesThrew = true;
        if (program.compileUpdatesShouldThrow &&
            error is IncrementalCompilationFailed) {
          statusMessage = "Expected error in compileUpdates.";
          result = null;
        } else {
          statusMessage = "Unexpected error in compileUpdates.";
          result = new Future.error(error, trace);
        }
        print(statusMessage);
        return result;
      });
      List<Command> update = await future;
      if (program.compileUpdatesShouldThrow) {
        updateFailedCount++;
        Expect.isTrue(
            compileUpdatesThrew,
            "Expected an exception in compileUpdates");
        Expect.isNull( update, "Expected update == null");
        return null;
      }

      for (Command command in update) {
        print(command);
        command.addTo(session.vmSocket);
      }

      await session.cont();

      for (String expected in program.messages) {
        Expect.isTrue(await session.iterator.moveNext());
        String actual = session.iterator.current;
        Expect.stringEquals(expected, actual);
        print("Got expected output: $actual");
      }

      // TODO(ahe): Enable SerializeScopeTestCase for multiple
      // parts.
      if (program.code is String) {
        await new SerializeScopeTestCase(
            program.code, test.incrementalCompiler.mainApp,
            test.incrementalCompiler.compiler).run();
      }
    }
  }).whenComplete(() async {

    var stderrFuture = new Future(() async {
      await for (String line in session.stderr) {
        hasStderrOutput = true;
        print('fletch_vm_stderr: $line');
      }
    });

    var stdoutFuture = new Future(() async {
      while (await session.iterator.moveNext()) {
        hasExtraStdoutOutput = true;
        print('fletch_vm_stdout: ${session.iterator.current}');
      }
    });

    var exitFuture = session.process.exitCode.then((int exitCode) {
      vmExitCode = exitCode;
      print("VM exited with exit code: $exitCode.");
    });

    if (session.running) {
      // The session is still alive. Rewrite the program so that
      // the process will terminate.
      for (Command command in [
               const commands_lib.PrepareForChanges(),
               new commands_lib.PushFromMap(MapId.methods, session.methodId),
               const commands_lib.PushBoolean(true),
               const commands_lib.ChangeMethodLiteral(0),
               const commands_lib.CommitChanges(1),
               const commands_lib.ProcessContinue()]) {
        print(command);
        command.addTo(session.vmSocket);
      }
      // Wait for process termination.
      Command response = await session.nextVmCommand();
      Expect.isTrue(response is commands_lib.ProcessTerminated,
                    "Unexpected command $response, expected ProcessTerminated");
      // Terminate the Fletch VM session so the Fletch VM will terminate.
      const commands_lib.SessionEnd().addTo(session.vmSocket);
      // Close the session socket to let the Dart VM running the tests
      // terminate.
      session.quit();
      await Future.wait([stderrFuture, stdoutFuture, exitFuture]);
    } else {
      // We either failed before we got to start a process or there
      // was an uncaught exception in the program. If there was an
      // uncaught exception the VM is intentionally hanging to give
      // the debugger a chance to inspect the state at the point of
      // the throw. Therefore, we explicitly have to kill the VM
      // process and close the session socket so the runner will
      // terminate.
      session.vmSocket.done.catchError((error, StackTrace stackTrace) {
        print("Ignoring socket error: $error");
        if (stackTrace != null) {
          print(stackTrace);
        }
      });
      session.process.kill();
      await Future.wait([stderrFuture, stdoutFuture, exitFuture]);
      session.quit();
    }
  });

  Expect.equals(0, vmExitCode, "Unexpected exit code from fletch VM");
  Expect.isFalse(hasExtraStdoutOutput, "Unexpected fletch_vm_stdout");
  Expect.isFalse(hasStderrOutput, "Unexpected fletch_vm_stderr");
}

class SerializeScopeTestCase extends CompilerTestCase {
  final String source;

  final String scopeInfo;

  final Compiler compiler = null; // TODO(ahe): Provide a copiler.

  SerializeScopeTestCase(
      this.source,
      LibraryElement library,
      Compiler compiler)
      : scopeInfo = computeScopeInfo(compiler, library),
        super(library.canonicalUri);

  Future run() {
    if (true) {
      // TODO(ahe): Remove this. We're temporarily bypassing scope validation.
      return new Future.value(null);
    }
    return loadMainApp().then(checkScopes);
  }

  void checkScopes(LibraryElement library) {
    var compiler = null;
    Expect.stringEquals(computeScopeInfo(compiler, library), scopeInfo);
  }

  Future<LibraryElement> loadMainApp() async {
    LibraryElement library =
        await compiler.libraryLoader.loadLibrary(scriptUri);
    if (compiler.mainApp == null) {
      compiler.mainApp = library;
    } else if (compiler.mainApp != library) {
      throw "Inconsistent use of compiler (${compiler.mainApp} != $library).";
    }
    return library;
  }

  static String computeScopeInfo(Compiler compiler, LibraryElement library) {
    ScopeInformationVisitor visitor =
        new ScopeInformationVisitor(compiler, library, 0);

    visitor.ignoreImports = true;
    visitor.sortMembers = true;
    visitor.indented.write('[\n');
    visitor.indentationLevel++;
    visitor.indented;
    library.accept(visitor, null);
    library.forEachLocalMember((Element member) {
      if (member.isClass) {
        visitor.buffer.write(',\n');
        visitor.indented;
        member.accept(visitor, null);
      }
    });
    visitor.buffer.write('\n');
    visitor.indentationLevel--;
    visitor.indented.write(']');
    return '${visitor.buffer}';
  }
}

void logger(x) {
  print(x);
}

String numberedLines(code) {
  if (code is! Map) {
    code = {'main.dart': code};
  }
  StringBuffer result = new StringBuffer();
  code.forEach((String fileName, String code) {
    result.writeln("==> $fileName <==");
    int lineNumber = 1;
    for (String text in splitLines(code)) {
      result.write("$lineNumber: $text");
      lineNumber++;
    }
  });
  return '$result';
}

List<String> splitLines(String text) {
  return text.split(new RegExp('^', multiLine: true));
}

Future<TestSession> runFletchVM(
    IoCompilerTestCase test,
    List<Command> commands) async {
  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

  List<String> vmOptions = <String>[
      '--port=${server.port}',
  ];

  String vmPath = test.incrementalCompiler.compiler.fletchVm.toFilePath();

  print("Running '$vmPath ${vmOptions.join(" ")}'");
  Process vmProcess = await Process.start(vmPath, vmOptions);
  var stdoutStream = vmProcess.stdout
      .transform(new Utf8Decoder())
      .transform(new LineSplitter());
  var stderrStream = vmProcess.stderr
      .transform(new Utf8Decoder())
      .transform(new LineSplitter());

  TestSession session;
  try {
    var vmSocket = await server.first;
    server.close();

    var compiler = test.incrementalCompiler.compiler;

    FunctionElement isMainDone =
        compiler.backend.fletchSystemLibrary.findLocal("isMainDone").getter;
    int methodId = compiler.backend.functionBuilders[isMainDone].methodId;

    session = new TestSession(
        vmSocket, compiler.helper,
        vmProcess,
        new StreamIterator(stdoutStream),
        stderrStream,
        methodId);
    session.vmCommands = new CommandReader(vmSocket).iterator;

    if (testSessionReset) {
      for (Command command in commands) {
        command.addTo(vmSocket);
      }

      // TODO(ager): Get rid of this again. We first run the program to
      // completion, then we reset the session and rebuild the program and carry
      // out the actual incremental compilation test.
      for (Command command in [
               const commands_lib.Debugging(),
               const commands_lib.ProcessSpawnForMain()]) {
        print(command);
        command.addTo(vmSocket);
      }

      session.running = true;
      const commands_lib.ProcessRun().addTo(vmSocket);
      await session.nextVmCommand();
      session.running = false;

      const commands_lib.SessionReset().addTo(vmSocket);
    }

    for (Command command in commands) {
      command.addTo(vmSocket);
    }

    for (Command command in [
        // Change isMainDone to always return false.
        const commands_lib.PrepareForChanges(),
        new commands_lib.PushFromMap(MapId.methods, methodId),
        const commands_lib.PushBoolean(false),
        const commands_lib.ChangeMethodLiteral(0),
        const commands_lib.CommitChanges(1),

        // Turn on debugging.
        const commands_lib.Debugging(),
        const commands_lib.ProcessSpawnForMain(),

        // Set a breakpoint in isMainDone at the first bytecode.
        new commands_lib.PushFromMap(MapId.methods, methodId),
        const commands_lib.ProcessSetBreakpoint(0)]) {
      print(command);
      command.addTo(vmSocket);
    }

    await session.nextVmCommand();
    await session.debugRun();

    return session;
  } catch (error, stackTrace) {
    print("An error occurred, shutting down.");
    print(error);
    if (stackTrace != null) {
      print(stackTrace);
    }
    var stderrFuture = new Future(() async {
      await for (String line in stderrStream) {
        print('fletch_vm_stderr: $line');
      }
    });
    var stdoutFuture = new Future(() async {
      if (session != null) {
        while (await session.iterator.moveNext()) {
          print('fletch_vm_stdout: ${session.iterator.current}');
        }
      } else {
        await for (String line in stdoutStream) {
          print('fletch_vm_stdout: $line');
        }
      }
    });
    if (session != null) {
      session.quit();
    }
    var exitFuture = session.process.exitCode.then((int exitCode) {
      print("VM exited with exit code: $exitCode.");
    });
    var futures =
        [stderrFuture, stdoutFuture, session.vmSocket.done, exitFuture];
    return Future.wait(futures).catchError((error, StackTrace stackTrace) {
      // An error already occurred, so we have to ignore any further
      // errors.
      print("Ignoring error: $error");
      if (stackTrace != null) {
        print(stackTrace);
      }
    }).then((_) => new Future.error(error, stackTrace));
  }
}

class TestSession extends Session {
  final Process process;
  final StreamIterator iterator;
  final Stream<String> stderr;
  final int methodId;

  TestSession(
      Socket vmSocket,
      compiler,
      this.process,
      this.iterator,
      this.stderr,
      this.methodId)
      : super(vmSocket, compiler);

  void exit(int exitCode) {
    // TODO(ahe/ager): Rename exit to something less conflicting with io.exit.
    throw "Unexpected exit from TestSession ($exitCode).";
  }
}

/// Invoked by ../../fletch_tests/fletch_test_suite.dart.
Future<Map<String, NoArgFuture>> listTests() {
  Map<String, NoArgFuture> result = <String, NoArgFuture>{};
  tests.forEach((String name, _) {
    String testName = 'incremental/encoded/$name';
    result[testName] = () => main(<String>[name]);
  });
  return new Future<Map<String, NoArgFuture>>.value(result);
}
