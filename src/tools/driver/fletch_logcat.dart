// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch_driver.logcat;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'fletch_help_text.dart' as help;
import 'cmd_line_utils.dart' as cmd;

// Server startup
main(List<String> args) {
  LogcatServer.performFromArgs(args);
}


// API for function call based invocation.
class LogcatServer {

  static performFromArgs(List<String> args) {
    if (args.length < 4) {
      print(help.LOGCAT_HELP_TEXT);
      return;
    }

    switch (args[1]) {
      case "start":
        if (args.length != 4) {
          print(help.LOGCAT_HELP_TEXT);
          return;
        }

        int portNumber = cmd.getPortNumberFromArg(args[2],
            help.LOGCAT_HELP_TEXT);
        if (portNumber < 0) return;

        String path = args[3];
        start(portNumber, path);
        break;

      default:
        print ("Unknown command: ${args[1]}");
        print (help.LOGCAT_HELP_TEXT);
    }
  }

  static start(int portNumber, String path) {
    print("Starting logcat server on $portNumber");
    _internalStart(portNumber);
  }


 static _internalStart(int portNumber) {
  // Only accept connections from localhost.
  final HOST = InternetAddress.LOOPBACK_IP_V4;

  HttpServer.bind(HOST, portNumber).then((server) {
    var handler = new ActionHandler(server);
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

static _handleBuffer(String jsonString, HttpRequest req, ActionHandler handler) {
  Map jsonData = JSON.decode(jsonString);

  if (!jsonData.containsKey("action"))
  {
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
  var ioChannel = print;
  HttpServer httpServer;
  Map<String, dynamic> actionMap;

  ActionHandler(this.httpServer) {
    actionMap = {
     "write" : write,
     "shutdown" : shutdown };
  }

  Future write(Map data, HttpRequest req) {
    /**
     * TODO(lukechurch): This is a placeholder implementation, until
     * the project control directory is established so we have a proper
     * log file target
     *
     * The use of a function that can be set on the argument is to allow
     * test infrastructure to inject a mock ioChannel.
     */
    return new Future.delayed(new Duration(seconds: 0), () => ioChannel(data));
  }

  Future shutdown(Map data, HttpRequest req) {
    return httpServer.close();
  }
}