// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dartino.vm_session;

const String BANNER = """
Starting session. Type 'help' for a list of commands.
""";

const String HELP = """
Commands:
  'help'                                show list of commands
  'r'/'run'                             start program
  'b [method name] [bytecode index]'    set breakpoint
  'bf <file> [line] [column]'           set breakpoint
  'bf <file> [line] [pattern]'          set breakpoint on first occurrence of
                                        the string pattern on the indicated line
  'd <breakpoint id>'                   delete breakpoint
  'lb'                                  list breakpoints
  's'                                   step until next expression,
                                        enters method invocations
  'n'                                   step until next expression,
                                        does not enter method invocations
  'fibers', 'lf'                        list all process fibers
  'finish'                              finish current method (step out)
  'restart'                             restart the selected frame
  'sb'                                  step bytecode, enters method invocations
  'nb'                                  step over bytecode, does not enter
                                        method invocations
  'c'                                   continue execution
  'bt'                                  backtrace
  'f <n>'                               select frame
  'l'                                   list source for frame
  'p <name>'                            print the value of local variable
  'p *<name>'                           print the structure of local variable
  'p'                                   print the values of all locals
  'processes', 'lp'                     list all processes
  'disasm'                              disassemble code for frame
  't <flag>'                            toggle one of the flags:
                                          - 'internal' : show internal frames
  'q'/'quit'                            quit the session
""";

class InputHandler {
  final Session session;
  final Stream<String> stream;
  final bool echo;
  final Uri base;

  bool printForTesting = false;

  String previousLine = '';

  int processPagingCount = 10;
  int processPagingCurrent = 0;

  InputHandler(this.session, this.stream, this.echo, this.base) {
    if (echo) printForTesting = true;
  }

  void printPrompt() => session.writeStdout('> ');

  writeStdout(String s) => session.writeStdout(s);

  writeStdoutLine(String s) => session.writeStdout("$s\n");

  Future handleLine(StreamIterator stream, SessionState state) async {
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
            await session.setBreakpoint(methodName: method, bytecodeIndex: bci);
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
          List<Uri> matches = session.findSourceFiles(file).toList()..sort(
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
            Breakpoint breakpoint = await session.setFileBreakpointFromPattern(
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
                await session.setFileBreakpoint(fileUri, line, columnNumber);
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
      case 'bt':
        if (!checkLoaded('cannot print backtrace')) {
          break;
        }
        BackTrace backtrace = await session.backTrace();
        if (backtrace == null) {
          writeStdoutLine('### failed to get backtrace for current program');
        } else {
          writeStdout(backtrace.format());
        }
        break;
      case 'f':
        var frame =
            (commandComponents.length > 1) ? commandComponents[1] : "-1";
        frame = int.parse(frame, onError: (_) => null);
        if (frame == null || !session.selectFrame(frame)) {
          writeStdoutLine('### invalid frame number: $frame');
        }
        break;
      case 'l':
        if (!checkLoaded('nothing to list')) {
          break;
        }
        BackTrace trace = await session.backTrace();
        String listing = trace != null ? trace.list(state) : null;
        if (listing != null) {
          writeStdoutLine(listing);
        } else {
          writeStdoutLine("### failed listing source");
        }
        break;
      case 'disasm':
        if (checkLoaded('cannot show bytecodes')) {
          BackTrace backtrace = await session.backTrace();
          String disassembly = backtrace != null ? backtrace.disasm() : null;
          if (disassembly != null) {
            writeStdout(disassembly);
          } else {
            writeStdoutLine(
                "### could not disassemble source for current frame");
          }
        }
        break;
      case 'c':
        if (checkRunning('cannot continue')) {
          await handleProcessStopResponse(await session.cont(), state);
        }
        break;
      case 'd':
        var id = (commandComponents.length > 1) ? commandComponents[1] : null;
        id = int.parse(id, onError: (_) => null);
        if (id == null) {
          writeStdoutLine('### invalid breakpoint number: $id');
          break;
        }
        Breakpoint breakpoint = await session.deleteBreakpoint(id);
        if (breakpoint == null) {
          writeStdoutLine("### invalid breakpoint id: $id");
          break;
        }
        printDeletedBreakpoint(breakpoint);
        break;
      case 'processes':
      case 'lp':
        if (checkRunning('cannot list processes')) {
          // Reset current paging point if not continuing from an 'lp' command.
          if (previousLine != 'lp' && previousLine != 'processes') {
            processPagingCurrent = 0;
          }

          List<int> processes = await session.processes();
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
            BackTrace stack = await session.processStack(processId);
            writeStdoutLine('\nprocess ${processId}');
            writeStdout(stack.format());
          }
          writeStdoutLine('');
        }
        break;
      case 'fibers':
      case 'lf':
        if (checkRunning('cannot show fibers')) {
          List<BackTrace> traces = await session.fibers();
          for (int fiber = 0; fiber < traces.length; ++fiber) {
            writeStdoutLine('\nfiber $fiber');
            writeStdout(traces[fiber].format());
          }
          writeStdoutLine('');
        }
        break;
      case 'finish':
        if (checkRunning('cannot finish method')) {
          await handleProcessStopResponse(await session.stepOut(), state);
        }
        break;
      case 'restart':
        if (!checkLoaded('cannot restart')) {
          break;
        }
        BackTrace trace = await session.backTrace();
        if (trace == null) {
          writeStdoutLine("### cannot restart when nothing is executing");
          break;
        }
        if (trace.length <= 1) {
          writeStdoutLine("### cannot restart entry frame");
          break;
        }
        await handleProcessStopResponse(await session.restart(), state);
        break;
      case 'lb':
        List<Breakpoint> breakpoints = session.breakpoints();
        if (breakpoints == null || breakpoints.isEmpty) {
          writeStdoutLine('### no breakpoints');
        } else {
          writeStdoutLine("### breakpoints:");
          for (var bp in breakpoints) {
            writeStdoutLine(BreakpointToString(bp));
          }
        }
        break;
      case 'p':
        if (!checkLoaded('nothing to print')) {
          break;
        }
        if (commandComponents.length <= 1) {
          List<RemoteObject> variables = await session.processAllVariables();
          if (variables.isEmpty) {
            writeStdoutLine('### No variables in scope');
          } else {
            for (RemoteObject variable in variables) {
              writeStdoutLine(session.remoteObjectToString(variable));
            }
          }
          break;
        }
        String variableName = commandComponents[1];
        RemoteObject variable;
        if (variableName.startsWith('*')) {
          variableName = variableName.substring(1);
          variable = await session.processVariableStructure(variableName);
        } else {
          variable = await session.processVariable(variableName);
        }
        if (variable == null) {
          writeStdoutLine('### no such variable: $variableName');
        } else {
          writeStdoutLine(session.remoteObjectToString(variable));
        }
        break;
      case 'q':
      case 'quit':
        await session.terminateSession();
        break;
      case 'r':
      case 'run':
        if (checkNotLoaded("use 'restart' to run again")) {
          await handleProcessStopResponse(await session.debugRun(), state);
        }
        break;
      case 's':
        if (checkRunning('cannot step to next expression')) {
          await handleProcessStopResponse(await session.step(), state);
        }
        break;
      case 'n':
        if (checkRunning('cannot go to next expression')) {
          await handleProcessStopResponse(await session.stepOver(), state);
        }
        break;
      case 'sb':
        if (checkRunning('cannot step bytecode')) {
          await handleProcessStopResponse(await session.stepBytecode(), state);
        }
        break;
      case 'nb':
        if (checkRunning('cannot step over bytecode')) {
          await handleProcessStopResponse(
              await session.stepOverBytecode(), state);
        }
        break;
      case 't':
        String toggle;
        if (commandComponents.length > 1) {
          toggle = commandComponents[1];
        }
        switch (toggle) {
          case 'internal':
            bool internalVisible = session.toggleInternal();
            writeStdoutLine(
                '### internal frame visibility set to: $internalVisible');
            break;
          case 'verbose':
            bool verbose = session.toggleVerbose();
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
    if (!session.terminated) printPrompt();
  }

  // This method is used to deal with the stopped process command responses
  // that can be returned when sending the Dartino VM a command request.
  Future handleProcessStopResponse(
      VmCommand response,
      SessionState state) async {
    String output = await session.processStopResponseToString(response, state);
    if (output != null && output.isNotEmpty) {
      writeStdout(output);
    }
  }

  bool checkLoaded([String postfix]) {
    if (!session.loaded) {
      String prefix = '### process not loaded';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return session.loaded;
  }

  bool checkNotLoaded([String postfix]) {
    if (session.loaded) {
      String prefix = '### process already loaded';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return !session.loaded;
  }

  bool checkRunning([String postfix]) {
    if (!session.running) {
      String prefix = '### process not running';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return session.running;
  }

  bool checkNotRunning([String postfix]) {
    if (session.running) {
      String prefix = '### process already running';
      writeStdoutLine(postfix != null ? '$prefix, $postfix' : prefix);
    }
    return !session.running;
  }

  Future<int> run(SessionState state) async {
    writeStdoutLine(BANNER);
    printPrompt();
    StreamIterator streamIterator = new StreamIterator(stream);
    while (await streamIterator.moveNext()) {
      try {
        await handleLine(streamIterator, state);
      } catch (e, s) {
        Future cancel = streamIterator.cancel()?.catchError((_) {});
        if (!session.terminated) {
          await session.terminateSession().catchError((_) {});
        }
        await cancel;
        return new Future.error(e, s);
      }
      if (session.terminated) {
        await streamIterator.cancel();
      }
    }
    if (!session.terminated) await session.terminateSession();
    return 0;
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
    String location = breakpoint.location(session.debugState);
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
}
