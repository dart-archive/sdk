// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.test.tests_with_expectations;

/// List of tests on this form:
///
///     ```
///     TEST_NAME
///     ==> a_test_file.dart <==
///     ... source code for a_test_file.dart ...
///     ==> another_test_file.dart.patch <==
///     ... source code for another_test_file.dart ...
///     ```
///
/// Filenames ending with ".patch" are special and are expanded into multiple
/// versions of a file. The parts of the file that vary between versions are
/// surrounded by `<<<<` and `>>>>` and the alternatives are separated by
/// `====`. For example:
///
///     ```
///     ==> file.txt.patch <==
///     first
///     <<<< "ex1"
///     v1
///     ==== "ex2"
///     v2
///     ==== "ex2"
///     v3
///     >>>>
///     last
///     ```
///
/// Will produce three versions of a file named `file.txt.patch`:
///
/// Version 1:
///     ```
///     first
///     v1
///     last
///     ```
/// With expectation `ex1`
///
/// Version 2:
///     ```
///     first
///     v2
///     last
///     ```
///
/// With expectation `ex2`
///
/// Version 3:
///     ```
///     first
///     v3
///     last
///     ```
///
/// With expectation `ex3`
///
///
/// It is possible to have several independent changes in the same patch. One
/// should only specify the expectations once. For example:
///
///     ==> main.dart.patch <==
///     class Foo {
///     <<<< "a"
///     ==== "b"
///       var bar;
///     >>>>
///     }
///     main() {
///       var foo = new Foo();
///     <<<<
///       print("a");
///     ====
///       print("b");
///     >>>>
///     }
///
/// Expectations
/// ------------
///
/// An expectation is a JSON string. It is decoded and the resulting object,
/// `o`, is converted to a [ProgramExpectation] in the following way:
///
/// * If `o` is a [String]: `new ProgramExpectation([o])`, otherwise
///
/// * if `o` is a [List]: `new ProgramExpectation(o)`, otherwise
///
/// * a new [ProgramExpectation] instance is instantiated with its fields
///   initialized to the corresponding properties of the JSON object. See
///   [ProgramExpectation.fromJson].
const List<String> tests = const <String>[
  r'''
hello_world
==> main.dart.patch <==
// Basic hello-world test
main() { print(
<<<< "Hello, World!"
'Hello, World!'
==== "Hello, Brave New World!"
'Hello, Brave New World!'
>>>>
); }

''',

  r'''
preserving_identity_hashcode
==> main.dart.patch <==
class Foo {
<<<< "Generated firstHashCode"
==== "firstHashCode == secondHashCode: true"
  var bar;
>>>>
}
Foo foo;
int firstHashCode;
main() {
<<<<
  foo = new Foo();
  firstHashCode = foo.hashCode;
  print("Generated firstHashCode");
====
  int secondHashCode = foo.hashCode;
  print("firstHashCode == secondHashCode: ${firstHashCode == secondHashCode}");
>>>>
}
''',

  r'''
instance_field_end
==> main.dart.patch <==
// Test that we can manipulate a field from an instance
// of a class from the end of the field list
class A {
  var x;
<<<< "instance is null"
  var y;
==== "x = 0"
==== "x = 0"
  int y;  // TODO(ahe): We don't add the field unless the tokens change
>>>>
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
''',

  r'''
instance_field_middle
==> main.dart.patch <==
// Test that we can manipulate a field from an instance
// of a class from the middle of the field list
class A {
  var x;
<<<< "instance is null"
  var y;
==== "x = 0"
==== ["x = 3","y = null","z = 2"]
  int y;  // TODO(ahe): We don't add the field unless the tokens change
>>>>
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
''',

  r'''
subclass_schema_1
==> main.dart.patch <==
// Test that schema changes affect subclasses correctly
class A {
  var x;
<<<< "instance is null"
  var y;
==== "x = 0"
==== ["x = 3","y = null","z = 2"]
  int y;  // TODO(ahe): We don't add the field unless the tokens change
>>>>
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
''',

  r'''
subclass_schema_2
==> main.dart.patch <==
// Test that schema changes affect subclasses of subclasses correctly
class A {
  var x;
<<<< "instance is null"
  var y;
==== "x = 0"
==== ["x = 3","y = null","z = 2"]
 int y;  // TODO(ahe): We don't add the field unless the tokens change
>>>>
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
''',

  r'''
super_schema
==> main.dart.patch <==
// Test that schema changes work in the presence of fields in the superclass
class A {
  var x;
}

class B extends A {
<<<< "instance is null"
  var y;
==== "x = 0"
==== ["x = 3","y = null","z = 2"]
  int y;  // TODO(ahe): We don't add the field unless the tokens change
>>>>
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
''',

  r'''
add_instance_field
==> main.dart.patch <==
// Test adding a field to a class works

class A {
<<<< ["instance is null","setter threw","getter threw"]
==== "v2"
  var x;
>>>>
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
''',

  r'''
remove_instance_field
==> main.dart.patch <==
// Test removing a field from a class works

class A {
<<<< ["instance is null","v1"]
  var x;
==== ["setter threw","getter threw"]
>>>>
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
''',

  r'''
two_updates
==> main.dart.patch <==
// Test that the test framework handles more than one update
main() { print(
<<<< "Hello darkness, my old friend"
'Hello darkness, my old friend'
==== "I've come to talk with you again"
'I\'ve come to talk with you again'
==== "Because a vision softly creeping"
'Because a vision softly creeping'
>>>>
); }

''',

  r'''
main_args
==> main.dart.patch <==
// Test that that isolate support works
main(arguments) { print(
<<<< "Hello, Isolated World!"
'Hello, Isolated World!'
==== "[]"
arguments
>>>>
); }

''',

  r'''
stored_closure
==> main.dart.patch <==
// Test that a stored closure changes behavior when updated

var closure;

foo(a, [b = 'b']) {
<<<< ["[closure] is null.","a b","a c"]
  print('$a $b');
==== ["b a","c a"]
  print('$b $a');
>>>>
}

main() {
  if (closure == null) {
    print('[closure] is null.');
    closure = foo;
  }
  closure('a');
  closure('a', 'c');
}


''',

  r'''
modify_static_method
==> main.dart.patch <==
// Test modifying a static method works

class C {
  static m() {
<<<< "v1"
  print('v1');
==== "v2"
  print('v2');
>>>>
  }
}
main() {
  C.m();
}


''',

  r'''
modify_instance_method
==> main.dart.patch <==
// Test modifying an instance method works

class C {
  m() {
<<<< ["instance is null","v1"]
  print('v1');
==== ["v2"]
  print('v2');
>>>>
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


''',

  r'''
stored_instance_tearoff
==> main.dart.patch <==
// Test that a stored instance tearoff changes behavior when updated

class C {
  m() {
<<<< ["closure is null","v1"]
  print('v1');
==== "v2"
  print('v2');
>>>>
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


''',

  r'''
remove_instance_method
==> main.dart.patch <==
// Test that deleting an instance method works

class C {
<<<< ["instance is null","v1"]
  m() {
    print('v1');
  }
==== {"messages":["threw"]}
>>>>
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


''',

  r'''
remove_instance_method_super_access
==> main.dart.patch <==
// Test that deleting an instance method works, even when accessed through
// super

class A {
  m() {
    print('v2');
  }
}
class B extends A {
<<<< ["instance is null","v1"]
  m() {
    print('v1');
  }
==== {"messages":["v2"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
>>>>
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


''',

  r'''
remove_top_level_method
==> main.dart.patch <==
// Test that deleting a top-level method works

<<<< ["instance is null","v1"]
toplevel() {
  print('v1');
}
==== {"messages":["threw"]}
>>>>
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


''',

  r'''
remove_static_method
==> main.dart.patch <==
// Test that deleting a static method works

class B {
<<<< ["instance is null","v1"]
  static staticMethod() {
    print('v1');
  }
==== {"messages":["threw"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
>>>>
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


''',

  r'''
newly_instantiated_class
==> main.dart.patch <==
// Test that a newly instantiated class is handled

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
<<<< ["instance is null","Called A.m"]
==== ["Called B.m"]
  } else {
    instance = new B();
>>>>
  }
  instance.m();
}


''',

  r'''
source_maps_no_throw
==> main.dart.patch <==
// Test that source maps don't throw exceptions

main() {
  print('a');
<<<< "a"
==== ["a","b","c"]
  print('b');
  print('c');
>>>>
}


''',

  r'''
newly_instantiated_class_X
==> main.dart.patch <==
// Test that a newly instantiated class is handled

// TODO(ahe): How is this different from the other test with same comment?

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
<<<< ["instance is null","Called A.m"]
==== ["Called B.m"]
  } else {
    instance = new B();
>>>>
  }
  instance.m();
}


''',

  r'''
newly_instantiated_class_with_fields
==> main.dart.patch <==
// Test that fields of a newly instantiated class are handled

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
<<<< "v1"
==== "v2"
  instance = new A('v2');
>>>>
  foo();
}


''',

  r'''
add_top_level_method
==> main.dart.patch <==
// Test that top-level functions can be added

<<<< "threw"
==== "v2"
foo() {
  print('v2');
}
>>>>
main() {
  try {
    foo();
  } catch(e) {
    print('threw');
  }
}


''',

  r'''
add_static_method
==> main.dart.patch <==
// Test that static methods can be added

class C {
<<<< "threw"
==== "v2"
  static foo() {
    print('v2');
  }
>>>>
}

main() {
  try {
    C.foo();
  } catch(e) {
    print('threw');
  }
}


''',

  r'''
add_instance_method
==> main.dart.patch <==
// Test that instance methods can be added

class C {
<<<< ["instance is null","threw"]
==== ["v2"]
  foo() {
    print('v2');
  }
>>>>
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


''',

  r'''
signature_change_top_level_method
==> main.dart.patch <==
// Test that top-level functions can have signature changed

<<<< "v1"
foo() {
  print('v1');
==== {"messages":["v2"]}
void foo() {
  print('v2');
>>>>
}

main() {
  foo();
}


''',

  r'''
signature_change_static_method
==> main.dart.patch <==
// Test that static methods can have signature changed

class C {
<<<< "v1"
  static foo() {
    print('v1');
==== {"messages":["v2"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
  static void foo() {
    print('v2');
>>>>
  }
}

main() {
  C.foo();
}


''',

  r'''
signature_change_instance_method
==> main.dart.patch <==
// Test that instance methods can have signature changed

class C {
<<<< ["instance is null","v1"]
  foo() {
    print('v1');
==== {"messages":["v2"]}
  void foo() {
    print('v2');
>>>>
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


''',

  r'''
add_class
==> main.dart.patch <==
// Test that adding a class is supported

<<<< "v1"
==== "v2"
class C {
  void foo() {
    print('v2');
  }
}
>>>>
main() {
<<<<
  print('v1');

====
  new C().foo();
>>>>
}


''',

  r'''
remove_class
==> main.dart.patch <==
// Test that removing a class is supported, using constructor

<<<< "v1"
class C {
}
==== {"messages":["v2"]}
>>>>
main() {
  try {
    new C();
    print('v1');
  } catch (e) {
    print('v2');
  }
}


''',

  r'''
remove_class_with_static_method
==> main.dart.patch <==
// Test that removing a class is supported, using a static method

<<<< "v1"
class C {
  static m() {
    print('v1');
  }
}
==== {"messages":["v2"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
>>>>
main() {
  try {
    C.m();
  } catch (e) {
    print('v2');
  }
}


''',

  r'''
change_supertype
==> main.dart.patch <==
// Test that changing the supertype of a class works

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
<<<< ["instance is null","v1"]
class C extends B {
==== ["instance is null","v2"]
// TODO(ahe): Should only print 'v2'
class C extends A {
>>>>
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


''',

  r'''
call_named_arguments_1
==> main.dart.patch <==
// Test that named arguments can be called

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
<<<< ["instance is null","v1"]
  instance.foo();
==== ["instance is null","v2"]
  // TODO(ahe): Should only print 'v2'
  instance.foo(named: 'v2');
>>>>
}


''',

  r'''
call_named_arguments_2
==> main.dart.patch <==
// Test that named arguments can be called

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
<<<< ["instance is null","v1"]
  instance.foo(named: 'v1');
==== ["instance is null","v2"]
   // TODO(ahe): Should only print 'v2'
  instance.foo();
>>>>
}


''',

  r'''
call_instance_tear_off_named
==> main.dart.patch <==
// Test that an instance tear-off with named parameters can be called

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
<<<< ["closure is null","v1"]
  closure();
==== "v2"
  closure(named: 'v2');
>>>>
}


''',

  r'''
lazy_static
==> main.dart.patch <==
// Test that a lazy static is supported

var normal;

<<<< "v1"
foo() {
  print(normal);
}
==== ["v2","lazy"]
var lazy = bar();

foo() {
  print(lazy);
}

bar() {
  print('v2');
  return 'lazy';
}

>>>>
main() {
  if (normal == null) {
    normal = 'v1';
  } else {
    normal = '';
  }
  foo();
}


''',

  r'''
super_classes_of_directly_instantiated
==> main.dart.patch <==
// Test that superclasses of directly instantiated classes are also emitted
class A {
}

class B extends A {
}

main() {
<<<< "v1"
  print('v1');
==== "v2"
  new B();
  print('v2');
>>>>
}


''',

  r'''
interceptor_classes
==> main.dart.patch <==
// Test that interceptor classes are handled correctly

main() {
<<<< "v1"
  print('v1');
==== "v2"
  ['v2'].forEach(print);
>>>>
}


''',

  r'''
newly_instantiated_superclasses_two_updates
==> main.dart.patch <==
// Test that newly instantiated superclasses are handled correctly when there
// is more than one change

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
<<<< "Called foo"
  new B().foo();
==== "Called foo"
  new B().foo();
==== "Called bar"
  new A().bar();
>>>>
}


''',

  r'''
newly_instantiated_subclases_two_updates
==> main.dart.patch <==
// Test that newly instantiated subclasses are handled correctly when there is
// more than one change

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
<<<< "Called foo"
  new A().foo();
==== "Called foo"
  new A().foo();
==== "Called bar"
  new B().bar();
>>>>
}


''',

  r'''
constants
==> main.dart.patch <==
// Test that constants are handled correctly

class C {
  final String value;
  const C(this.value);
}

main() {
<<<< "v1"
  print(const C('v1').value);
==== "v2"
  print(const C('v2').value);
>>>>
}


''',

  r'''
add_compound_instance_field
==> main.dart.patch <==
// Test that an instance field can be added to a compound declaration

class C {
<<<< ["[instance] is null","v1","[instance.y] threw"]
  int x;
==== {"messages":["v1","v2"],"compileUpdatesShouldThrow":1}
  // TODO(ahe): Should not throw
  int x, y;
>>>>
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


''',

  r'''
remove_compound_instance_field
==> main.dart.patch <==
// Test that an instance field can be removed from a compound declaration

class C {
<<<< ["[instance] is null","v1","v2"]
  int x, y;
==== {"messages":["v1","[instance.y] threw"],"compileUpdatesShouldThrow":1}
  // TODO(ahe): Should not throw
  int x;
>>>>
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


''',

  r'''
static_field_to_instance_field
==> main.dart.patch <==
// Test that a static field can be made an instance field

class C {
<<<< ["[instance] is null","v1","[instance.x] threw"]
  static int x;
==== {"messages":["[C.x] threw","v2"],"compileUpdatesShouldThrow":1}
  // TODO(ahe): Should not throw
  int x;
>>>>
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


''',

  r'''
instance_field_to_static_field
==> main.dart.patch <==
// Test that instance field can be made static

class C {
<<<< ["[instance] is null","[C.x] threw","v1"]
  int x;
==== {"messages":["v2","[instance.x] threw"],"compileUpdatesShouldThrow":1}
  // TODO(ahe): Should not throw
  static int x;
>>>>
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


''',

  r'''
compound_constants
==> main.dart.patch <==
// Test compound constants

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
<<<< ["A(v1)","B(v1)"]
  print(const A('v1'));
  print(const B('v1'));
==== ["B(A(v2))","A(B(v2))"]
  print(const B(const A('v2')));
  print(const A(const B('v2')));
>>>>
}


''',

  r'''
constants_of_new_classes
==> main.dart.patch <==
// Test constants of new classes

class A {
  final value;
  const A(this.value);

  toString() => 'A($value)';
}
<<<< "A(v1)"
==== ["A(v2)","B(v2)","B(A(v2))","A(B(v2))"]
class B {
  final value;
  const B(this.value);

  toString() => 'B($value)';
}

>>>>
main() {
<<<<
  print(const A('v1'));

====
  print(const A('v2'));
  print(const B('v2'));
  print(const B(const A('v2')));
  print(const A(const B('v2')));
>>>>
}


''',

  r'''
change_in_part
==> main.dart <==
// Test that a change in a part is handled
library test.main;

part 'part.dart';


==> part.dart.patch <==
part of test.main;

main() {
<<<< "Hello, World!"
  print('Hello, World!');
==== "Hello, Brave New World!"
  print('Hello, Brave New World!');
>>>>
}
''',

  r'''
change_library_name
==> main.dart.patch <==
// Test that a change in library name is handled
<<<< "Hello, World!"
library test.main1;
==== {"messages":["Hello, World!"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
library test.main2;
>>>>

main() {
  print('Hello, World!');
}
''',

  r'''
add_import
==> main.dart.patch <==
// Test that adding an import is handled
<<<< "Hello, World!"
==== {"messages":["Hello, World!"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
import 'dart:core';
>>>>

main() {
  print('Hello, World!');
}
''',

  r'''
add_export
==> main.dart.patch <==
// Test that adding an export is handled
<<<< "Hello, World!"
==== {"messages":["Hello, World!"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
export 'dart:core';
>>>>

main() {
  print('Hello, World!');
}
''',

  r'''
add_part
==> main.dart.patch <==
// Test that adding a part is handled
library test.main;

<<<< "Hello, World!"
==== {"messages":["Hello, World!"],"compileUpdatesShouldThrow":1}
// TODO(ahe): Should not throw
part 'part.dart';
>>>>

main() {
  print('Hello, World!');
}


==> part.dart <==
part of test.main
''',

  r'''
multiple_libraries
==> main.dart <==
// Test that changes in multiple libraries is handled
import 'library1.dart' as lib1;
import 'library2.dart' as lib2;

main() {
  lib1.method();
  lib2.method();
}


==> library1.dart.patch <==
library test.library1;

method() {
<<<< ["lib1.v1","lib2.v1"]
  print('lib1.v1');
==== ["lib1.v2","lib2.v2"]
  print('lib1.v2');
==== ["lib1.v3","lib2.v3"]
  print('lib1.v3');
>>>>
}


==> library2.dart.patch <==
library test.library2;

method() {
<<<<
  print('lib2.v1');
====
  print('lib2.v2');
====
  print('lib2.v3');
>>>>
}
''',

  r'''
bad_stack_trace_repro
==> main.dart.patch <==
// Reproduces a problem where the stack trace includes an old method that
// should have been removed by the incremental compiler
main() {
  bar();
}

bar() {
<<<< []
  foo(true);
==== []
  foo(false);
>>>>
}

foo(a) {
  if (a) throw "throw";
}
''',

  r'''
compile_time_error_001
==> main.dart.patch <==
// Reproduce a crash when a compile-time error is added
main() {
<<<< []
==== {"messages":[],"compileUpdatesShouldThrow":1}
// TODO(ahe): compileUpdates shouldn't throw, a compile-time error should be
// reported instead
  do for while if;
>>>>
}
''',

  r'''
compile_time_error_002
==> main.dart.patch <==
// Reproduce a crash when a *recoverable* compile-time error is added
main() {
<<<< []
==== []
  new new();
>>>>
}
''',

  r'''
compile_time_error_003
==> main.dart.patch <==
// Reproduce a crash when a compile-time error is reported on a new class
<<<< []
==== {"messages":[],"compileUpdatesShouldThrow":1}
// TODO(ahe): compileUpdates shouldn't throw, a compile-time error should be
// reported instead
abstract class A implements bool default F {
  A();
}
>>>>

class F {
<<<<
====
  factory A() { return null; }
>>>>
}

main() {
<<<<
====
  new A();
>>>>
}
''',

  r'''
compile_time_error_004
==> main.dart.patch <==
// Reproduce a crash when a class has a bad hierarchy
<<<< []
typedef A(C c);
==== {"messages":[],"compileUpdatesShouldThrow":1}
// TODO(ahe): compileUpdates shouldn't throw, a compile-time error should be
// reported instead
typedef A(Class c);
>>>>

typedef B(A a);

typedef C(B b);

class Class {
<<<<
====
  A a;
>>>>
}

void testA(A a) {}

void main() {
  testA(null);
}
''',

  r'''
compile_time_error_005
==> main.dart.patch <==
// Regression for crash when attempting to reuse method with compile-time
// error.
main() {
<<<< "Compile error"
  var funcnuf = (x) => ((x))=((x)) <= (x);
==== []
  // TODO(ahe): Should expect "Hello"
  print("Hello");
>>>>
}
''',

  r'''
generic_types_001
==> main.dart.patch <==
<<<< []
class A<T> {
}
==== {"messages":[],"compileUpdatesShouldThrow":1}
// TODO(ahe): compileUpdates shouldn't throw, we should handle generic types
// instead
>>>>

main() {
<<<<
  new A();
====
>>>>
}
''',

  r'''
add_named_mixin_application
==> main.dart.patch <==
// Test that we can add a mixin application.
class A {}
<<<< []
==== {"messages":[],"compileUpdatesShouldThrow":1}
// TODO(ahe): compileUpdates shouldn't throw, we should be able to handle named
// mixin applications.
class C = Object with A;
>>>>
main() {
  new A();
<<<<
====
  new C();
>>>>
}
''',

  r'''
remove_named_mixin_application
==> main.dart.patch <==
// Test that we can remove a mixin application.
class A {}
<<<< []
class C = Object with A;
==== {"messages":[],"compileUpdatesShouldThrow":1}
// TODO(ahe): compileUpdates shouldn't throw, we should be able to handle named
// mixin applications.
>>>>
main() {
  new A();
<<<<
  new C();
====
>>>>
}
''',

  r'''
unchanged_named_mixin_application
==> main.dart.patch <==
// Test that we can handle a mixin application that doesn't change.
class A {}
class C = Object with A;

main() {
  new C();
<<<< []
==== {"messages":[],"compileUpdatesShouldThrow":1}
  // TODO(ahe): compileUpdates shouldn't throw, we should be able to handle
  // named mixin applications.
  new C();
>>>>
}
''',

  r'''
bad_diagnostics
==> main.dart.patch <==
// Test that our diagnostics handler doesn't crash
main() {
<<<< []
==== []
  // This is a long comment to guarantee that we have a position beyond the end
  // of the first version of this file.
  NoSuchClass c = null; // Provoke a warning to exercise the diagnostic handler.
>>>>
}
''',

  r'''
super_is_parameter
==> main.dart.patch <==
<<<< []
class A<S> {
==== {"messages":[],"compileUpdatesShouldThrow":1}
// TODO(ahe): compileUpdates shouldn't throw.
class A<S extends S> {
>>>>
  S field;
}

class B<T> implements A<T> {
  T field;
}

main() {
  new B<int>();
}
''',

  r'''
closure_capture
==> main.dart.patch <==
main() {
  var a = "hello";
<<<< "hello"
  print(a);
==== {"messages":["hello from closure"],"compileUpdatesShouldThrow":1}
  // TODO(ahe): compileUpdates shouldn't throw, we should be able to handle
  // capture variables in closures.
  (() => print('$a from closure'))();
>>>>
}
''',

  r'''
add_top_level_field
==> main.dart.patch <==
// Test that we can add a top-level field.
<<<< "0"
==== "1"
  const c = 1;
>>>>

main() {
<<<<
  print(0);
====
  print(c);
>>>>
}
''',
];
