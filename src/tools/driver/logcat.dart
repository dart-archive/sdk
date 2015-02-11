// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library driver.logcat;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'help_text.dart' as help;
import 'cmd_line_utils.dart' as cmd;

main(List<String> args) {
  LogcatServer.performFromArgs(args);
}

class Logger {
  // This method needs migrating to call the log server.
  static void log(message) => print(message);
}

class LogcatServer {
  static performFromArgs(List<String> args) {
    if (args.length != 3) {
      print("logcat requires exactly 3 arguments");
      print(help.LOGCAT_HELP_TEXT);
      exit(1);
    }

    switch (args[0]) {
      case "start":
        if (args.length != 3) {
          print(help.LOGCAT_HELP_TEXT);
          exit(1);
        }

        int portNumber = cmd.getPortNumberFromArg(args[1],
            help.LOGCAT_HELP_TEXT);
        if (portNumber < 0) exit(1);

        String path = args[2];
        start(portNumber, path);
        break;

      default:
        print ("Unknown command: ${args[0]}");
        print (help.LOGCAT_HELP_TEXT);
        exit(1);
    }
  }

  static void start(int portNumber, String path) {
    print("Starting logcat server on $portNumber, path: $path");
    _internalStart(portNumber, path);
  }

  static void _internalStart(int portNumber, String path) {
    // Only accept connections from localhost.
    final HOST = InternetAddress.LOOPBACK_IP_V4;

    HttpServer.bind(HOST, portNumber).then((server) {
      var handler = new ActionHandler(server, path);
      server.listen((req) {
        ContentType contentType = req.headers.contentType;
        if (req.method != 'POST') {
          req.response.statusCode = HttpStatus.METHOD_NOT_ALLOWED;
          req.response.write("Unsupported request: ${req.method}.");
          req.response.close();
          return;
        }

        BytesBuilder builder = new BytesBuilder();
        req.listen(
            (buffer) { builder.add(buffer); },
            onDone: () {
              String jsonString = UTF8.decode(builder.takeBytes());
              _handleBuffer(jsonString, req, handler);
            });
      });
    });
  }

  static void _handleBuffer(
      String jsonString,
      HttpRequest req,
      ActionHandler handler) {
    Map jsonData = JSON.decode(jsonString);

    if (!jsonData.containsKey("action")) {
      req.response.statusCode = HttpStatus.BAD_REQUEST;
      req.response.close();
      return;
    }

    String actionName = jsonData["action"];
    if (actionName.startsWith("_")) {
      req.response.statusCode = HttpStatus.FORBIDDEN;
      req.response.close();
      return;
    }

    if (!handler.actionMap.containsKey(actionName)) {
      req.response.statusCode = HttpStatus.NOT_FOUND;
      req.response.close();
      return;
    }

    handler.actionMap[actionName](jsonData, req);
  }
}

class ActionHandler {
  final HttpServer httpServer;
  final String path;
  /**
   * TODO(lukechurch): This is a placeholder implementation, until
   * the project control directory is established so we have a proper
   * log file target
   *
   * The use of a function that can be set on the argument is to allow
   * test infrastructure to inject a mock ioChannel.
   */
  var ioChannel = (data, path) => print("$path -> $data");
  Map<String, dynamic> actionMap;

  ActionHandler(this.httpServer, this.path) {
    actionMap = {
     "write" : write,
     "shutdown" : shutdown };
  }

  Future write(Map data, HttpRequest req) {
    return new Future.delayed(new Duration(seconds: 0),
        () => ioChannel(data["data"], path));
  }

  Future shutdown(Map data, HttpRequest req) {
    print ("Shutting down logcat");
    return httpServer.close(force: true);
  }
}
