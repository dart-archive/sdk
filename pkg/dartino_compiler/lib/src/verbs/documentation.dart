// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.documentation;

const String synopsis = """
Manages interactions with the dartino compiler and runtime.
Example: dartino run sample.dart

Usage: dartino <action> [<argument>]...
 where <action> is one of the following:""";

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
             Run the compiled code on the Dartino VM and break at the main
             method

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

const String createDocumentation = """
   create session <name> [with <settings file>]
             Create a new session with the given name.  Read settings from
             <settings file> (defaults to '.dartino-settings').

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
             Attach to Dartino VM on the given socket
""";

const String runDocumentation = """
   run [<file>] [in session remote]
             Run <file> on the Dartino VM. If no <file> is given, run the
             previous file. Defaults to running on the local PC;
             use 'in session remote' to run remotely.
""";

const String endDocumentation = """
   x-end session <name>
             End the named session
""";

const String servicecDocumentation = """
   x-servicec <file>
             Compile service IDL file named <file> to custom Dartino interface
""";

const String exportDocumentation = """
   export [<dartfile>] to <snapshot>
             Compile <dartfile> and create a snapshot in <snapshot>. If no
             <dartfile> is given, export the previously compiled file
""";

const String quitDocumentation = """
   quit      Quits the Dartino background process, and terminates all
             Dartino sessions currently running.
""";

const String showDocumentation = """
   show devices
             Show all Dartino capable devices connected
             directly or available on the network

   show log [in session <name>]
             Show log for given session
""";

// TODO(lukechurch): Review UX.
const String upgradeDocumentation = """
   x-upgrade agent with <package-file> [in session <session>]
             Upgrade the agent used in session to the version provided in the
             .deb package <package-file>
""";

// TODO(lukechurch): Review UX.
const String downloadToolsDocumentation = """
   x-download-tools
             Downloads the third party tools required for MCU developemnt.
             This is currently GCC ARM Embedded and OpenOCD.
""";

const String buildDocumentation = """
   build <file>
             Build flashable image containing the Dart code in <file>.
             The flashable image will be called <basename of file>.bin.

             Currently this will build an image for the STM32F746G Discovery
             board only.
""";

const String flashDocumentation = """
   flash <file>
             Build flashable image containing the Dart code in <file> and
             flash it to a connected board.

             Currently this will build and flash an image for the STM32F746G
             Discovery board only.
""";
