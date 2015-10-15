// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'test.dart' show
    Test;

import 'package:expect/expect.dart' show
    Expect;

import 'package:servicec/util.dart' show
    camelize,
    underscore;

class CamelizeTest extends Test {
  CamelizeTest()
    : super('camelize');

  Future perform() {
    // Simple uses.
    Expect.equals("HelloWorld", camelize("hello_world"));
    Expect.throws(() => camelize("hello world"), null,
                  "Should fail on bad symbols");
    Expect.equals("hello_world", underscore("HelloWorld"));
    Expect.equals("hello_world", underscore("helloWorld"));
    Expect.throws(() => underscore("hello world"), null,
                  "Should fail on bad symbols");

    // Multiple underscores.
    Expect.equals("HelloThereWorld", camelize("hello_there_world"));
    Expect.equals("HelloThereBigWideWorldHowAreYou",
        camelize("hello_there_big_wide_world_how_are_you"));
    Expect.equals("HelloWorld", camelize("hello___world"));
    Expect.equals("Hello", camelize("___hello"));
    Expect.equals("Hello", camelize("___Hello"));
    Expect.equals("Hello", camelize("Hello___"));
    Expect.equals("Hello", camelize("hello___"));
    Expect.equals("HelloWorld", camelize("___hello___world___"));
    Expect.equals("Just1Chance", camelize("just_1_chance"));

    // Multiple words.
    Expect.equals("hello_there_world", underscore("HelloThereWorld"));
    Expect.equals("hello_there_big_wide_world_how_are_you",
        underscore("HelloThereBigWideWorldHowAreYou"));
    Expect.equals("parsed_html", underscore("parsedHtml"));

    // Acronyms and digits.
    Expect.equals("d_e_b_u_g", underscore("DEBUG"));
    Expect.equals("h_o_w_a_b_o_u_t_c_o_n_s_t_a_n_t_s",
                  underscore("HOW_ABOUT_CONSTANTS"));
    Expect.equals("employee_i_d", underscore("employeeID"));
    Expect.equals("parsed_h_t_m_l", underscore("parsedHTML"));
    Expect.equals("Just1chance", camelize("just_1chance"));
    Expect.equals("just_1chance", underscore("Just1chance"));
    Expect.equals("just_1_chance", underscore("Just1Chance"));

    // Bad argument names
    Expect.throws(() => camelize("___"), null,
                  "Should fail on input without alphabetic characters (1)");
    Expect.throws(() => camelize("__1word__"), null,
                  "Should fail on input without alphabetic characters (2)");
    Expect.throws(() => camelize("__1word"), null,
                  "Should fail on input without alphabetic characters (3)");
    Expect.throws(() => camelize("1word__"), null,
                  "Should fail on input without alphabetic characters (4)");
    Expect.throws(() => camelize("1word"), null,
                  "Should fail on input without alphabetic characters (5)");

    Expect.throws(() => camelize("hello_world™"), null,
                  "Should fail on non-ascii characters (1)");
    Expect.throws(() => camelize("hello_world⛐ "), null,
                  "Should fail on non-ascii characters (2)");
    Expect.throws(() => camelize("▁▂▃▄▅▆▇█▉"), null,
                  "Should fail on non-ascii characters (3)");


    // Underscores in input for underscore.
    Expect.equals("_", underscore("_"));
    Expect.equals(  "hello_world"  , underscore(  "Hello_World"  ));
    Expect.equals( "_hello"        , underscore( "_Hello"        ));
    Expect.equals(  "hello_"       , underscore(  "Hello_"       ));
    Expect.equals( "_hello_world"  , underscore( "_HelloWorld"   ));
    Expect.equals("__hello_world"  , underscore("__HelloWorld"   ));
    Expect.equals(  "hello_world_" , underscore(  "HelloWorld_"  ));
    Expect.equals(  "hello_world__", underscore(  "HelloWorld__" ));
    Expect.equals( "_hello_world_" , underscore( "_HelloWorld_"  ));
    Expect.equals("__hello_world__", underscore("__HelloWorld__" ));
    Expect.equals(  "hello_world"  , underscore(  "Hello_World"  ));
    Expect.equals(  "hello___world", underscore(  "Hello___World"));
  }
}
