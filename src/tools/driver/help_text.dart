// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library driver.help_text;

const HELP_TEXT = r'''
Usage: fletch command

Manages, edits, runs and closes Fletch projects and programs.

Common commands:
  help  <command>     - show detailed help for a command.
  init  <path>        - create/connect to a Fletch project.
  show  <thing>       - show details about the thing.
  start <entrypoint>  - start running at the entrypoint.
''';

const INIT_HELP_TEXT = r'''
Usage: fletch init <path>

Creates a Fletch project in the specified path if one doesn't already exist.
Then connects to that project, ready to receive further commands.
''';

const SHOW_HELP_TEXT = r'''
Usage fletch show <thing> [name]

Shows information about things in the project. If no name is given all the
things are listed, otherwise detail about the specific thing is listed.

Supported things:
  class[es]
  diff[s]
  entrypoint[s]
  method[s]
  poi
''';

const START_HELP_TEXT = r'''
Usage fletch start [entrypoint]

Begin execution at the specified entrypoint. If no entrypoint is specified
main is executed if it is present and unique.
''';

const LOGCAT_HELP_TEXT = r'''
Usage fletch logcat <command>

Manages information logged by Fletch

Commands:
  start <port number> <path>
      - start a logcat server on the specified port and target
''';

const FAIL_HELP_TEXT = r'''
Usage: fletch command

Try 'fletch help' for a list of the commands available.
''';
