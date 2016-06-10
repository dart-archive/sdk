// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import "dart:async";

import "dart:convert" show
    UTF8;

import "dart:io" show
    File;

import "src/hub/session_manager.dart" show
    SessionState;

import "debug_state.dart";

import "vm_context.dart";

import 'vm_commands.dart' show
    ConnectionError,
    ProcessCompileTimeError,
    ProcessBreakpoint,
    ProcessTerminated,
    UncaughtException,
    VmCommand;

const String BANNER = """
Starting session. Type 'help' for a list of commands.
""";

const String HELP = """
Commands:
  'help'                                show list of commands
  'r/run'                               start program
  'b [method name] [bytecode index]'    set breakpoint
  'bf <file> [line] [column]'           set breakpoint
  'bf <file> [line] [pattern]'          set breakpoint on first occurrence of
                                        the string pattern on the indicated line
  'd/delete <breakpoint id>'            delete breakpoint
  'lb'                                  list breakpoints
  's/step'                              step until next expression,
                                        enters method invocations
  'n/next'                              step until next expression,
                                        does not enter method invocations
  'lf', 'fibers'                        list all process fibers
  'finish'                              finish current method (step out)
  'restart'                             restart the selected frame
  'sb'                                  step bytecode, enters method invocations
  'nb'                                  step over bytecode, does not enter
                                        method invocations
  'c'                                   continue execution
  'bt'                                  backtrace
  'f/frame <n>'                         select frame
  'l/list'                              list source for frame
  'p/print <name>(.<field>)*'           print a value starting from a local
                                        variable
  'p/print *<name>(.<field>)*'          print the structure of a value starting
                                        from a local variable
  'p/print'                             print the values of all locals
  'lp/processes'                        list all processes
  'disasm/disassemble'                  disassemble code for frame
  't/toggle <flag>'                     toggle one of the flags:
                                          - 'internal' : show internal frames
                                          - 'verbose' : verbose stack traces
  'q/quit'                              quit the session
""";

class CommandLineDebugger {
  final DartinoVmContext vmContext;
  final Stream<String> stream;
  final bool echo;
  final Uri base;
  final Sink<List<int>> stdout;

  bool quitDebugger = false;

  bool printForTesting = false;

  bool get colorsDisabled => printForTesting;
  bool verbose = true;

  String previousLine = '';

  int processPagingCount = 10;
  int processPagingCurrent = 0;

  CommandLineDebugger(
      this.vmContext, this.stream, this.base, this.stdout, {bool echo: false})
    : echo = echo,
      printForTesting = echo;

  void printPrompt() => writeStdout('> ');

  writeStdout(String s) => stdout.add(UTF8.encode(s));

  writeStdoutLine(String s) => writeStdout("$s\n");

  Future handleLine(StreamIterator stream) async {
    String line = stream.current;
    if (line.isEmpty) line = previousLine;
    if (line.isEmpty) {
      printPrompt();
      return;
    }
    if (echo) writeStdoutLine(line);
    List<String> commandComponents =
        line.split(' ').where((s) => s.isNotEmpty).toList();
    String command = commandComponents[0];
    switch (command) {
      case 'help':
        writeStdoutLine(HELP);
        break;
      case 'break':
      case 'b':
        var method =
            (commandComponents.length > 1) ? commandComponents[1] : 'main';
        var bci =
            (commandComponents.length > 2) ? commandComponents[2] : '0';
        bci = int.parse(bci, onError: (_) => null);
        if (bci == null) {
          writeStdoutLine('### invalid bytecode index: $bci');
          break;
        }
        List<Breakpoint> breakpoints =
            await vmContext.setBreakpoint(
                methodName: method, bytecodeIndex: bci);
        if (breakpoints != null) {
          for (Breakpoint breakpoint in breakpoints) {
            printSetBreakpoint(breakpoint);
          }
        } else {
          writeStdoutLine(
              "### failed to set breakpoint at method: $method index: $bci");
        }
        break;
      case 'bf':
        var file =
            (commandComponents.length > 1) ? commandComponents[1] : '';
        var line =
            (commandComponents.length > 2) ? commandComponents[2] : '1';
        var columnOrPattern =
            (commandComponents.length > 3) ? commandComponents[3] : '1';

        List<Uri> files = <Uri>[];

        if (await new File.fromUri(base.resolve(file)).exists()) {
          // If the supplied file resolved directly to a file use it.
          files.add(base.resolve(file));
        } else {
          // Otherwise search for possible matches.
          List<Uri> matches = vmContext.findSourceFiles(file).toList()..sort(
              (a, b) => a.toString().compareTo(b.toString()));
          Iterable<int> selection = await select(
              stream,
              "Multiple matches for file pattern $file",
              matches.map((uri) =>
                uri.toString().replaceFirst(base.toString(), '')));
          for (int selected in selection) {
            files.add(matches.elementAt(selected));
          }
        }

        if (files.isEmpty) {
          writeStdoutLine('### no matching file found for: $file');
          break;
        }

        line = int.parse(line, onError: (_) => null);
        if (line == null || line < 1) {
          writeStdoutLine('### invalid line number: $line');
          break;
        }

        List<Breakpoint> breakpoints = <Breakpoint>[];
        int columnNumber = int.parse(columnOrPattern, onError: (_) => null);
        if (columnNumber == null) {
          for (Uri fileUri in files) {
            Breakpoint breakpoint =
                await vmContext.setFileBreakpointFromPattern(
                    fileUri, line, columnOrPattern);
            if (breakpoint == null) {
              writeStdoutLine(
                  '### failed to set breakpoint for pattern $columnOrPattern ' +
                  'on $fileUri:$line');
            } else {
              breakpoints.add(breakpoint);
            }
          }
        } else if (columnNumber < 1) {
          writeStdoutLine('### invalid column number: $columnOrPattern');
          break;
        } else {
          for (Uri fileUri in files) {
            Breakpoint breakpoint =
                await vmContext.setFileBreakpoint(fileUri, line, columnNumber);
            if (breakpoint == null) {
              writeStdoutLine(
                  '### failed to set breakpoint ' +
                  'on $fileUri:$line:$columnNumber');
            } else {
              breakpoints.add(breakpoint);
            }
          }
        }
        if (breakpoints.isNotEmpty) {
          for (Breakpoint breakpoint in breakpoints) {
            printSetBreakpoint(breakpoint);
          }
        } else {
          writeStdoutLine(
              "### failed to set any breakpoints");
        }
        break;
      case 'backtrace':
      case 'bt':
        if (!checkSpawned('cannot print backtrace')) {
          break;
        }
        BackTrace backtrace = await vmContext.backTrace();
        if (backtrace == null) {
          writeStdoutLine('### failed to get backtrace for current program');
        } else {
          writeStdout(backtrace.format());
        }
        break;
      case 'frame':
      case 'f':
        var frame =
            (commandComponents.length > 1) ? commandComponents[1] : "-1";
        frame = int.parse(frame, onError: (_) => null);
        if (frame == null || !vmContext.selectFrame(frame)) {
          writeStdoutLine('### invalid frame number: $frame');
        }
        break;
      case 'list':
      case 'l':
        if (!checkSpawned('nothing to list')) {
          break;
        }
        BackTrace trace = await vmContext.backTrace();
        String listing = trace?.list(colorsDisabled: colorsDisabled);
        if (listing != null) {
          writeStdoutLine(listing);
        } else {
          writeStdoutLine("### failed listing source");
        }
        break;
      case 'disassemble':
      case 'disasm':
        if (checkSpawned('cannot show bytecodes')) {
          BackTrace backtrace = await vmContext.backTrace();
          String disassembly = backtrace != null ? backtrace.disasm() : null;
          if (disassembly != null) {
            writeStdout(disassembly);
          } else {
            writeStdoutLine(
                "### could not disassemble source for current frame");
          }
        }
        break;
      case 'continue':
      case 'c':
        if (checkPaused('cannot continue')) {
          await handleProcessStopResponse(await vmContext.cont());
        }
        break;
      case 'delete':
      case 'd':
        var id = (commandComponents.length > 1) ? commandComponents[1] : null;
        id = int.parse(id, onError: (_) => null);
        if (id == null) {
          writeStdoutLine('### invalid breakpoint number: $id');
          break;
        }
        Breakpoint breakpoint = await vmContext.deleteBreakpoint(id);
        if (breakpoint == null) {
          writeStdoutLine("### invalid breakpoint id: $id");
          break;
        }
        printDeletedBreakpoint(breakpoint);
        break;
      case 'processes':
      case 'lp':
        if (checkPausedOrRunning('cannot list processes')) {
          // Reset current paging point if not continuing from an 'lp' command.
          if (previousLine != 'lp' && previousLine != 'processes') {
            processPagingCurrent = 0;
          }

          List<int> processes = await vmContext.processes();
          processes.sort();

          int count = processes.length;
          int start = processPagingCurrent;
          int end;
          if (start + processPagingCount < count) {
            processPagingCurrent += processPagingCount;
            end = processPagingCurrent;
          } else {
            processPagingCurrent = 0;
            end = count;
          }

          if (processPagingCount < count) {
            writeStdout("displaying range [$start;${end-1}] ");
            writeStdoutLine("of $count processes");
          }
          for (int i = start; i < end; ++i) {
            int processId = processes[i];
            BackTrace stack = await vmContext.processStack(processId);
            writeStdoutLine('\nprocess ${processId}');
            writeStdout(stack.format());
          }
          writeStdoutLine('');
        }
        break;
      case 'fibers':
      case 'lf':
        if (checkPausedOrRunning('cannot show fibers')) {
          List<BackTrace> traces = await vmContext.fibers();
          for (int fiber = 0; fiber < traces.length; ++fiber) {
            writeStdoutLine('\nfiber $fiber');
            writeStdout(traces[fiber].format());
          }
          writeStdoutLine('');
        }
        break;
      case 'finish':
        if (checkPaused('cannot finish method')) {
          await handleProcessStopResponse(await vmContext.stepOut());
        }
        break;
      case 'restart':
        if (!checkSpawned('cannot restart')) {
          break;
        }
        BackTrace trace = await vmContext.backTrace();
        if (trace == null) {
          writeStdoutLine("### cannot restart when nothing is executing");
          break;
        }
        if (trace.length <= 1) {
          writeStdoutLine("### cannot restart entry frame");
          break;
        }
        await handleProcessStopResponse(await vmContext.restart());
        break;
      case 'lb':
        List<Breakpoint> breakpoints = vmContext.breakpoints();
        if (breakpoints == null || breakpoints.isEmpty) {
          writeStdoutLine('### no breakpoints');
        } else {
          writeStdoutLine("### breakpoints:");
          for (var bp in breakpoints) {
            writeStdoutLine(BreakpointToString(bp));
          }
        }
        break;
      case 'print':
      case 'p':
        if (!checkSpawned('nothing to print')) {
          break;
        }
        if (commandComponents.length <= 1) {
          List<RemoteObject> variables = await vmContext.processAllVariables();
          if (variables.isEmpty) {
            writeStdoutLine('### No variables in scope');
          } else {
            for (RemoteObject variable in variables) {
              writeStdoutLine(vmContext.remoteObjectToString(variable));
            }
          }
          break;
        }
        String access = commandComponents[1];
        bool getStructure = false;

        if (access.startsWith('*')) {
          access = access.substring(1);
          getStructure = true;
        }
        List<String> names = access.split(".");

        RemoteObject value = getStructure
            ? await vmContext.processVariableStructure(names)
            : await vmContext.processVariable(names);

        if (value is RemoteErrorObject) {
          writeStdoutLine("### could not access '$access': ${value.message}");
        } else {
          writeStdoutLine(vmContext.remoteObjectToString(value));
        }
        break;
      case 'q':
      case 'quit':
        quitDebugger = true;
        break;
      case 'r':
      case 'run':
        if (checkNotScheduled("use 'restart' to run again")) {
          await handleProcessStopResponse(await vmContext.startRunning());
        }
        break;
      case 'step':
      case 's':
        if (checkPaused('cannot step to next expression')) {
          await handleProcessStopResponse(await vmContext.step());
        }
        break;
      case 'n':
        if (checkPaused('cannot go to next expression')) {
          await handleProcessStopResponse(await vmContext.stepOver());
        }
        break;
      case 'sb':
        if (checkPaused('cannot step bytecode')) {
          await handleProcessStopResponse(await vmContext.stepBytecode());
        }
        break;
      case 'nb':
        if (checkPaused('cannot step over bytecode')) {
          await handleProcessStopResponse(await vmContext.stepOverBytecode());
        }
        break;
      case 'toggle':
      case 't':
        String toggle;
        if (commandComponents.length > 1) {
          toggle = commandComponents[1];
        }
        switch (toggle) {
          case 'internal':
            bool internalVisible = vmContext.toggleInternal();
            writeStdoutLine(
                '### internal frame visibility set to: $internalVisible');
            break;
          case 'verbose':
            bool verbose = toggleVerbose();
            writeStdoutLine('### verbose printing set to: $verbose');
            break;
          case 'testing':
            printForTesting = !printForTesting;
            writeStdoutLine('### print for testing set to: $printForTesting');
            break;
          default:
            writeStdoutLine('### invalid flag $toggle');
            break;
        }
        break;
      default:
        writeStdoutLine('### unknown command: $command');
        break;
    }
    previousLine = line;
  }

  bool toggleVerbose() => verbose = !verbose;

  // This method is used to deal with the stopped process command responses
  // that can be returned when sending the Dartino VM a command request.
  Future handleProcessStopResponse(
      VmCommand response) async {
    String output = await processStopResponseToString(
        vmContext,
        response,
        colorsDisabled: colorsDisabled,
        verbose: verbose);
    if (output != null && output.isNotEmpty) {
      writeStdout(output);
    }
    if (response is ProcessTerminated) {
      // TODO(sigurdm): Do we want to keep the program open for inspection?
      await vmContext.terminate();
    }
  }

  bool checkSpawned([String postfix]) {
    if (!vmContext.isSpawned) {
      String prefix = '### process not scheduled';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return vmContext.isSpawned;
  }

  bool checkNotScheduled([String postfix]) {
    if (vmContext.isScheduled) {
      String prefix = '### process already scheduled';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return !vmContext.isScheduled;
  }

  bool checkPaused([String postfix]) {
    if (!vmContext.isPaused) {
      String prefix = '### process not paused';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return vmContext.isPaused;
  }

  bool checkPausedOrRunning([String postfix]) {
    if (!vmContext.isPaused && !vmContext.isRunning) {
      String prefix = '### process not running';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return vmContext.isPaused;
  }

  bool checkRunning([String postfix]) {
    if (!vmContext.isRunning) {
      String prefix = '### process not running';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return vmContext.isRunning;
  }

  bool checkNotRunning([String postfix]) {
    if (vmContext.isRunning) {
      String prefix = '### process already running';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return !vmContext.isRunning;
  }

  Future<int> run(SessionState state, {Uri snapshotLocation}) async {
    await vmContext.initialize(state, snapshotLocation: snapshotLocation);
    writeStdoutLine(BANNER);
    StreamIterator<String> streamIterator = new StreamIterator(stream);

    Future<bool> getNext() async {
      if (vmContext.isTerminated) return false;
      printPrompt();
      return await streamIterator.moveNext();
    }

    while (!quitDebugger && await getNext()) {
      try {
        await handleLine(streamIterator);
      } catch (e, s) {
        Future cancel = streamIterator.cancel()?.catchError((_) {});
        if (!vmContext.isTerminated) {
          await vmContext.terminate().catchError((_) {});
        }
        await cancel;
        return new Future.error(e, s);
      }
      if (vmContext.isTerminated) {
        await streamIterator.cancel();
      }
    }
    if (!vmContext.isTerminated) await vmContext.terminate();
    return vmContext.interactiveExitCode;
  }

  // Prompt the user to select among a set of choices.
  // Returns a set of indexes that are the chosen indexes from the input set.
  // If the size of choices is less then two, then the result is that the full
  // input set is selected without prompting the user. Otherwise the user is
  // interactively prompted to choose a selection.
  Future<Iterable<int>> select(
      StreamIterator stream,
      String message,
      Iterable<String> choices) async {
    int length = choices.length;
    if (length == 0) return <int>[];
    if (length == 1) return <int>[0];
    writeStdout("$message. ");
    writeStdoutLine("Please select from the following choices:");
    int i = 1;
    int pad = 2 + "$length".length;
    for (String choice in choices) {
      writeStdoutLine("${i++}".padLeft(pad) + ": $choice");
    }
    writeStdoutLine('a'.padLeft(pad) + ": all of the above");
    writeStdoutLine('n'.padLeft(pad) + ": none of the above");
    while (true) {
      printPrompt();
      bool hasNext = await stream.moveNext();
      if (!hasNext) {
        writeStdoutLine("### failed to read choice input");
        return <int>[];
      }
      String line = stream.current;
      if (echo) writeStdoutLine(line);
      if (line == 'n') {
        return <int>[];
      }
      if (line == 'a') {
        return new List<int>.generate(length, (i) => i);
      }
      int choice = int.parse(line, onError: (_) => 0);
      if (choice > 0 && choice <= length) {
        return <int>[choice - 1];
      }
      writeStdoutLine("Invalid choice: $choice");
      writeStdoutLine("Please select a number between 1 and $length, " +
                      "'a' for all, or 'n' for none.");
    }
  }

  // Printing routines. When running in "testing" mode, these will print
  // messages with relatively stable content (eg, not a line:column format).

  String BreakpointToString(Breakpoint breakpoint) {
    if (printForTesting) return breakpoint.toString();
    int id = breakpoint.id;
    String name = breakpoint.methodName;
    String location = breakpoint.location(vmContext.debugState);
    return "$id: $name @ $location";
  }

  void printSetBreakpoint(Breakpoint breakpoint) {
    writeStdout("### set breakpoint ");
    writeStdoutLine(BreakpointToString(breakpoint));
  }

  void printDeletedBreakpoint(Breakpoint breakpoint) {
    writeStdout("### deleted breakpoint ");
    writeStdoutLine(BreakpointToString(breakpoint));
  }

  // This method is a helper method for computing the default output for one
// of the stop command results. There are currently the following stop
// responses:
//   ProcessTerminated
//   ProcessBreakpoint
//   UncaughtException
//   ProcessCompileError
//   ConnectionError
  static Future<String> processStopResponseToString(
      DartinoVmContext vmContext,
      VmCommand response,
      {bool verbose: true,
      bool colorsDisabled: true}) async {
    if (response is UncaughtException) {
      StringBuffer sb = new StringBuffer();
      // Print the exception first, followed by a stack trace.
      RemoteObject exception = await vmContext.uncaughtException();
      sb.writeln(vmContext.exceptionToString(exception));
      BackTrace trace = await vmContext.backTrace();
      assert(trace != null);
      sb.write(trace.format());
      String result = '$sb';
      if (!result.endsWith('\n')) result = '$result\n';
      return result;
    } else if (response is ProcessBreakpoint) {
      // Print the current line of source code.
      BackTrace trace = await vmContext.backTrace();
      assert(trace != null);
      BackTraceFrame topFrame = trace.visibleFrame(0);
      if (topFrame != null) {
        String result;
        if (verbose) {
          result = topFrame.list(
              colorsDisabled: colorsDisabled,
              contextLines: 0);
        } else {
          result = topFrame.shortString();
        }
        if (!result.endsWith('\n')) result = '$result\n';
        return result;
      }
    } else if (response is ProcessCompileTimeError) {
      // TODO(sigurdm): add information to ProcessCompileTimeError about the
      // specific error and print here. (issue #494).
      return '';
    } else if (response is ProcessTerminated) {
      return '### process terminated\n';

    } else if (response is ConnectionError) {
      return '### lost connection to the virtual machine\n';
    }
    return '';
  }
}
