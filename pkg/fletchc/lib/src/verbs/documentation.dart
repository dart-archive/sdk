// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.documentation;

const String synopsis = """
Usage: fletch <action> [<argument>]...
Manages interactions with the fletch compiler and runtime.
Example: fletch run sample.dart

<action> is one of the following:""";

const String debugDocumentation = """
   debug
             Start an interactive debug session

   debug backtrace
             Print the current stack trace

   debug break <location>
             Set a breakpoint at <location>. <Location> must have one of the
             formats methodName@bytecodeIndex or filename:line:column

   debug continue
             Resume execution of a program when at a breakpoint

   debug delete-breakpoint <n>
             Delete breakpoint with id <n>

   debug disasm
             Print bytecodes for the selected frame

   debug fibers
             Print a stack trace for all fibers

   debug finish
             Finish execution of the current frame

   debug frame <n>
             Select frame <n> in the stack trace

   debug list
             Print source listing for the selected frame

   debug list breakpoints
             Print a list of all breakpoints

   debug print <name>
             Print the value of the local variable with the given name

   debug print *<name>
             Print the structure of the local variable with the given name

   debug print-all
             Print the value of all local variables

   debug restart
             Restart the selected frame

   debug run-to-main
             Run the compiled code on the Fletch VM and break at the main method

   debug step
             Step to next source position

   debug step-bytecode
             Step one bytecode

   debug step-over
             Step to next source location; do not follow calls

   debug step-over-bytecode
             Step one bytecode; do not follow calls

   debug toggle internal
             Toggle visibility of internal frames
""";

const String helpDocumentation = """
   help all  List all commands
""";

const String shutdownDocumentation = """
   shutdown  Shut down the background Fletch process
""";

const String createDocumentation = """
   create session <name> [with <settings file>]
             Create a new session with the given name.  Read settings from
             <settings file> (defaults to '.fletch-settings').

             Settings are specified in JSON (comments allowed):

{
  // Location of the package configuration file (a relative URI)
  "packages": ".packages",

  // A list of strings that are passed to the compiler
  "options": ["--verbose"],

  // Values of compile-time constants. These will appear as the results
  // expressions like:
  //
  //   const bool.fromEnvironment("<name>")
  //   const int.fromEnvironment("<name>")
  //   const String.fromEnvironment("<name>")
  //
  "constants": {
    "<name>": "<value>",
  }
}
""";

const String compileDocumentation = """
   compile <file> [in session <name>]
             Compile <file>
""";

const String attachDocumentation = """
   attach tcp_socket [<host>:]<port>
             Attach to Fletch VM on the given socket
""";

const String runDocumentation = """
   run [<file>]
             Run <file> on the Fletch VM. Compile <file> if neeed. If no <file>
             is given, run the previously compiled file.
""";

const String endDocumentation = """
   x-end session <name>
             End the named session
""";

const String servicecDocumentation = """
   x-servicec <file>
             Compile service IDL file named <file> to custom Fletch interface
""";

const String exportDocumentation = """
   export [<dartfile>] to <snapshot>
             Compile <dartfile> and create a snapshot in <snapshot>. If no
             <dartfile> is given, export the previously compiled file
""";

const String quitDocumentation = """
   quit      Quits the fletch background process. Warning: will terminate all
             fletch sessions currently running
""";
