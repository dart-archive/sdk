// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.documentation;

const String debugDocumentation = """
   debug
             Start an interactive debug session

   debug run-to-main
             Run the compiled code on the Fletch VM and break at the main method

   debug backtrace
             Print the current stack trace

   debug continue
             Resume execution of a program when at a breakpoint

   debug break LOCATION
             Set a breakpoint at LOCATION. LOCATION should have one of the
             formats methodName@bytecodeIndex or filename:line:column
""";

const String helpDocumentation = """
   help      Display this information.
             Use 'fletch help all' for a list of all actions
""";

const String compileAndRunDocumentation = """
   compile-and-run [options] dartfile
             Compile and run dartfile in a temporary session.  This is a
             provisionary feature that will be removed shortly
""";

const String shutdownDocumentation = """
   shutdown  Terminate the background fletch compiler process
""";

const String createDocumentation = """
   create    Create something
""";

const String compileDocumentation = """
   compile file FILE
             Compile file named FILE
""";

const String showDocumentation = """
   show      List things or show information about a thing
""";

const String attachDocumentation = """
   attach tcp_socket [HOST:]PORT
             Attach to Fletch VM on the given socket
""";

const String runDocumentation = """
   x-run     Run the compiled code on the Fletch VM
""";

const String endDocumentation = """
   x-end session NAME
             End the named session
""";

const String servicecDocumentation = """
   x-servicec file FILE
             Compile service IDL file named FILE to custom fletch interface
""";
