// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// An implementation of the vm service-protocol in terms of a DartinoVmContext.
/// Processes are mapped to isolates.
// TODO(sigurdm): Handle processes better.
// TODO(sigurdm): Find a way to represent fibers.
// TODO(sigurdm): Use https://pub.dartlang.org/packages/json_rpc_2 for serving.

import "dart:async" show Future;

import 'dart:convert' show JSON;

import 'dart:io' show File, HttpServer, WebSocket, WebSocketTransformer;

import 'hub/session_manager.dart' show SessionState;

import 'guess_configuration.dart' show dartinoVersion;

import '../debug_state.dart'
    show
        BackTrace,
        BackTraceFrame,
        Breakpoint,
        RemoteArray,
        RemoteErrorObject,
        RemoteInstance,
        RemoteObject,
        RemoteValue;

import '../vm_context.dart' show DartinoVmContext, DebugListener;

import '../dartino_system.dart'
    show DartinoFunction, DartinoFunctionKind, DartinoSystem;

import 'debug_info.dart' show DebugInfo, ScopeInfo, SourceLocation;

import 'dartino_compiler_implementation.dart'
    show DartinoCompilerImplementation;
import 'element_utils.dart';

import '../program_info.dart' show Configuration;
import '../vm_commands.dart'
    show
        Array,
        Boolean,
        ClassValue,
        DartValue,
        Double,
        Instance,
        Integer,
        NullValue,
        StringValue;

import 'package:collection/collection.dart' show binarySearch;

import 'package:compiler/src/scanner/scanner.dart' show Scanner;
import 'package:compiler/src/tokens/token.dart' show Token;
import 'package:compiler/src/io/source_file.dart' show SourceFile;
import 'package:compiler/src/elements/visitor.dart' show BaseElementVisitor;
import 'package:compiler/src/elements/elements.dart'
    show
        ClassElement,
        CompilationUnitElement,
        Element,
        FieldElement,
        FunctionElement,
        LibraryElement,
        MemberElement,
        ScopeContainerElement;

const bool logging = const bool.fromEnvironment("dartino-log-debug-server");

class DebugServer {
  Future<int> serveSingleShot(SessionState state,
      {int port: 0, Uri snapshotLocation}) async {
    HttpServer server = await HttpServer.bind("127.0.0.1", port);
    // The Atom Dartino plugin waits for "localhost:<port-number>"
    // to determine the observatory port for debugging.
    print("localhost:${server.port}");
    WebSocket socket = await server.transform(new WebSocketTransformer()).first;
    await new DebugConnection(state, socket, snapshotLocation: snapshotLocation)
        .serve();
    await state.vmContext.terminate();
    await server.close();
    return 0;
  }
}

class DebugConnection implements DebugListener {
  final Map<String, bool> streams = new Map<String, bool>();

  DartinoVmContext get vmContext => state.vmContext;
  final SessionState state;
  final WebSocket socket;
  final Uri snapshotLocation;

  final Map<Uri, List<int>> tokenTables = new Map<Uri, List<int>>();

  Map lastPauseEvent;

  DebugConnection(this.state, this.socket, {this.snapshotLocation});

  List<int> makeTokenTable(CompilationUnitElement compilationUnit) {
    // TODO(sigurdm): Are these cached somewhere?
    Token t = new Scanner(compilationUnit.script.file).tokenize();
    List<int> result = new List<int>();
    while (t.next != t) {
      result.add(t.charOffset);
      t = t.next;
    }
    return result;
  }

  void send(Map message) {
    if (logging) {
      print("Sending ${JSON.encode(message)}");
    }
    socket.add(JSON.encode(message));
  }

  void setStream(String streamId, bool value) {
    streams[streamId] = value;
  }

  Map<String, CompilationUnitElement> scripts =
      new Map<String, CompilationUnitElement>();

  Future<Map> frameDesc(BackTraceFrame frame, int index) async {
    List<Map> vars = new List<Map>();
    for (ScopeInfo current = frame.scopeInfo();
        current != ScopeInfo.sentinel;
        current = current.previous) {
      RemoteValue remoteValue =
          await vmContext.processLocal(index, current.local.slot);
      vars.add({
        "type": "BoundVariable",
        "name": current.name,
        "value": instanceRef(
            remoteValue.value, "objects/$index.${current.local.slot}"),
      });
    }
    return {
      "type": "Frame",
      "index": index,
      "function": functionRef(frame.function),
      "code": {
        "id": "code-id", //TODO(danrubel): what is the unique id here?
        "type": "@Code",
        "name": "code-name", // TODO(sigurdm): How to create a name here?
        "kind": "Dart",
      },
      "location": locationDesc(frame.sourceLocation(), false),
      "vars": vars,
    };
  }

  Map locationDesc(SourceLocation location, bool includeEndToken) {
    // TODO(sigurdm): Investigate when this happens.
    if (location == null || location.file == null)
      return {
      "type": "SourceLocation",
      "script": scriptRef(Uri.parse('file:///unknown')),
      "tokenPos": 0,
    };
    Uri uri = location.file.uri;
    // TODO(sigurdm): Avoid this. The uri should be the same as we get from
    // `CompilationUnit.script.file.uri`.
    uri = new File(new File.fromUri(uri).resolveSymbolicLinksSync()).uri;

    int tokenPos =
        binarySearch(tokenTables[location.file.uri], location.span.begin);

    Map result = {
      "type": "SourceLocation",
      "script": scriptRef(location.file.uri),
      "tokenPos": tokenPos,
    };
    if (includeEndToken) {
      int endTokenPos =
          binarySearch(tokenTables[location.file.uri], location.span.end);
      result["endTokenPos"] = endTokenPos;
    }

    return result;
  }

  Map isolateRef(int isolateId) {
    return {
      "name": "Isolate $isolateId",
      "id": "isolates/$isolateId",
      "fixedId": true,
      "type": "@Isolate",
      "number": "$isolateId"
    };
  }

  Map libraryRef(LibraryElement library) {
    return {
      "type": "@Library",
      "id": "libraries/${library.canonicalUri}",
      "fixedId": true,
      "name": "${library.canonicalUri}",
      "uri": "${library.canonicalUri}",
    };
  }

  Map libraryDesc(LibraryElement library) {
    return {
      "type": "Library",
      "id": "libraries/${library.canonicalUri}",
      "fixedId": true,
      "name": "${library.canonicalUri}",
      "uri": "${library.canonicalUri}",
      // TODO(danrubel): determine proper values for the next entry
      "debuggable": true,
      // TODO(sigurdm): The following fields are not used by the atom-debugger.
      // We might want to include them to get full compatibility with the
      // observatory.
      "dependencies": [],
      "classes": [],
      "variables": [],
      "functions": [],
      "scripts": library.compilationUnits
          .map((CompilationUnitElement compilationUnit) =>
              scriptRef(compilationUnit.script.resourceUri))
          .toList()
    };
  }

  Map breakpointDesc(Breakpoint breakpoint) {
    DebugInfo debugInfo =
        state.vmContext.debugState.getDebugInfo(breakpoint.function);
    SourceLocation location = debugInfo.locationFor(breakpoint.bytecodeIndex);
    return {
      "type": "Breakpoint",
      "breakpointNumber": breakpoint.id,
      "id": "breakpoints/${breakpoint.id}",
      "fixedId": true,
      "resolved": true,
      "location": locationDesc(location, false),
    };
  }

  Map scriptRef(Uri uri) {
    return {
      "type": "@Script",
      "id": "scripts/${uri}",
      "fixedId": true,
      "uri": "${uri}",
      "_kind": "script"
    };
  }

  Map scriptDesc(CompilationUnitElement compilationUnit) {
    String text = compilationUnit.script.text;
    SourceFile file = compilationUnit.script.file;
    List<List<int>> tokenPosTable = [];
    List<int> tokenTable = tokenTables[compilationUnit.script.resourceUri];
    int currentLine = -1;
    for (int i = 0; i < tokenTable.length; i++) {
      int line = file.getLine(tokenTable[i]);
      int column = file.getColumn(line, tokenTable[i]);
      if (line != currentLine) {
        currentLine = line;
        // The debugger lines starts from 1.
        tokenPosTable.add([currentLine + 1]);
      }
      tokenPosTable.last.add(i);
      tokenPosTable.last.add(column);
    }
    return {
      "type": "Script",
      "id": "scripts/${compilationUnit.script.resourceUri}",
      "fixedId": true,
      "uri": "${compilationUnit.script.resourceUri}",
      "library": libraryRef(compilationUnit.library),
      "source": text,
      "tokenPosTable": tokenPosTable,
      "lineOffset": 0, // TODO(sigurdm): What is this?
      "columnOffset": 0, // TODO(sigurdm): What is this?
    };
  }

  String functionKind(DartinoFunctionKind kind) {
    return {
      DartinoFunctionKind.NORMAL: "RegularFunction",
      DartinoFunctionKind.LAZY_FIELD_INITIALIZER: "Stub",
      DartinoFunctionKind.INITIALIZER_LIST: "RegularFunction",
      DartinoFunctionKind.PARAMETER_STUB: "Stub",
      DartinoFunctionKind.ACCESSOR: "GetterFunction"
    }[kind];
  }

  Map functionRef(DartinoFunction function) {
    String name = function.name;
    //TODO(danrubel): Investigate why this happens.
    if (name == null || name.isEmpty) name = 'unknown';
    return {
      "type": "@Function",
      "id": "functions/${function.functionId}",
      "fixedId": true,
      "name": "${name}",
      // TODO(sigurdm): All kinds of owner.
      "owner": libraryRef(function?.element?.library ?? state.compiler.mainApp),
      "static": function.element?.isStatic ?? false,
      "const": function.element?.isConst ?? false,
      "_kind": functionKind(function.kind),
    };
  }

  Map functionDesc(DartinoFunction function) {
    FunctionElement element = function.element;
    return {
      "type": "Function",
      "id": "functions/${function.functionId}",
      // TODO(sigurdm): All kinds of owner.
      "owner": libraryRef(element.library),
      "static": element.isStatic,
      "const": element.isConst,
      "_kind": functionKind(function.kind),
    };
  }

  Map classRef(ClassElement classElement) {
    if (classElement == null) {
      return {"type": "@Class", "id": "unknown", "name": "unknown class"};
    }
    String symbolicName =
        "${classElement.library.canonicalUri}.${classElement.name}";
    return {
      "type": "@Class",
      "id": "classes/$symbolicName",
      "name": "${classElement.name}",
    };
  }

  Map instanceRef(DartValue value, String id) {
    int classId;
    Element classElement;
    String stringValue;
    String kind;
    int length;
    String name;
    if (value is Instance) {
      kind = "PlainInstance";
      classId = value.classId;
    } else if (value is Integer) {
      kind = "Int";
      classElement = vmContext.compiler.compiler.backend.intImplementation;
      stringValue = "${value.value}";
    } else if (value is StringValue) {
      kind = "String";
      classElement = vmContext.compiler.compiler.backend.stringImplementation;
      stringValue = value.value;
    } else if (value is Boolean) {
      kind = "Bool";
      classElement = vmContext.compiler.compiler.backend.boolImplementation;
      stringValue = "${value.value}";
    } else if (value is Double) {
      kind = "Double";
      classElement = vmContext.compiler.compiler.backend.doubleImplementation;
      stringValue = "${value.value}";
    } else if (value is ClassValue) {
      kind = "Type";
      Element element =
          vmContext.dartinoSystem.classesById[value.classId].element;
      classElement = vmContext.compiler.compiler.backend.typeImplementation;
      name = "${element}";
    } else if (value is NullValue) {
      kind = "Null";
      classElement = vmContext.compiler.compiler.backend.nullImplementation;
      stringValue = "null";
    } else if (value is Array) {
      kind = "List";
      classElement = vmContext.compiler.compiler.backend.listImplementation;
      length = value.length;
    } else {
      throw "Unexpected remote value $value";
    }
    Map classReference = classRef(
        classElement ?? vmContext.dartinoSystem.classesById[classId]?.element);
    Map result = {
      "type": "@Instance",
      "id": id,
      "kind": kind,
      "class": classReference,
    };
    if (stringValue != null) {
      result["valueAsString"] = stringValue;
    }
    if (length != null) {
      result["length"] = length;
    }
    if (name != null) {
      result["name"] = name;
    }
    return result;
  }

  Map instanceDesc(RemoteObject remoteObject, String id) {
    // TODO(sigurdm): Allow inspecting any frame.
    assert(remoteObject is! RemoteErrorObject);
    if (remoteObject is RemoteInstance) {
      int classId = remoteObject.instance.classId;
      Element classElement =
          vmContext.dartinoSystem.classesById[classId].element;
      List<FieldElement> fieldElements = computeFields(classElement);
      assert(fieldElements.length == remoteObject.fields.length);
      List fields = new List();
      for (int i = 0; i < fieldElements.length; i++) {
        FieldElement fieldElement = fieldElements[i];
        fields.add({
          "type": "BoundField",
          "decl": {
            "type": "@Field",
            "name": fieldElement.name,
            "owner": classRef(fieldElement.contextClass),
            "declaredType": null, // TODO(sigurdm): fill this in.
            "const": fieldElement.isConst,
            "final": fieldElement.isFinal,
            "static": fieldElement.isStatic,
          },
          "value": instanceRef(remoteObject.fields[i], "$id.$i"),
        });
      }
      return <String, dynamic>{
        "type": "Instance",
        "id": id,
        "kind": "PlainInstance",
        "class": classRef(classElement),
        "fields": fields,
      };
    } else if (remoteObject is RemoteArray) {
      // TODO(sigurdm): Handle large arrays. (Issue #536).
      List elements = new List();
      for (int i = 0; i < remoteObject.array.length; i++) {
        elements.add(instanceRef(remoteObject.values[i], "$id.$i"));
      }
      return <String, dynamic>{
        "type": "Instance",
        "id": id,
        "kind": "List",
        "class":
            classRef(vmContext.compiler.compiler.backend.listImplementation),
        "elements": elements,
      };
    } else if (remoteObject is RemoteValue) {
      Map instance = instanceRef(remoteObject.value, id);
      instance["type"] = "Instance";
      return instance;
    } else {
      throw "Unexpected remote object kind";
    }
  }

  initialize(DartinoCompilerImplementation compiler) {
    for (LibraryElement library in compiler.libraryLoader.libraries) {
      cacheScripts(LibraryElement library) {
        for (CompilationUnitElement compilationUnit
            in library.compilationUnits) {
          Uri uri = compilationUnit.script.file.uri;
          scripts["scripts/$uri"] = compilationUnit;
          tokenTables[uri] = makeTokenTable(compilationUnit);
        }
      }
      cacheScripts(library);
      if (library.isPatched) {
        cacheScripts(library.patch);
      }
    }
  }

  serve() async {
    vmContext.listeners.add(this);

    await vmContext.initialize(state, snapshotLocation: snapshotLocation);

    initialize(state.compiler.compiler);

    await for (var message in socket) {
      if (message is! String) throw "Expected String";
      var decodedMessage = JSON.decode(message);
      if (logging) {
        print("Received $decodedMessage");
      }

      if (decodedMessage is! Map) throw "Expected Map";
      var id = decodedMessage['id'];
      void sendResult(Map result) {
        Map message = {"jsonrpc": "2.0", "result": result, "id": id};
        send(message);
      }
      void sendError(Map error) {
        Map message = {"jsonrpc": "2.0", "error": error, "id": id};
        send(message);
      }
      switch (decodedMessage["method"]) {
        case "streamListen":
          setStream(decodedMessage["params"]["streamId"], true);
          sendResult({"type": "Success"});
          break;
        case "streamCancel":
          setStream(decodedMessage["streamId"], false);
          sendResult({"type": "Success"});
          break;
        case "getVersion":
          sendResult({"type": "Version", "major": 3, "minor": 4});
          break;
        case "getVM":
          List<int> isolates = await state.vmContext.processes();
          sendResult({
            "type": "VM",
            "name": "dartino-vm",
            "architectureBits": {
              Configuration.Offset64BitsDouble: 64,
              Configuration.Offset64BitsFloat: 64,
              Configuration.Offset32BitsDouble: 32,
              Configuration.Offset32BitsFloat: 32,
            }[vmContext.configuration],
            // TODO(sigurdm): Can we give a better description?
            "targetCPU": "${vmContext.configuration}",
            // TODO(sigurdm): Can we give a better description?
            "hostCPU": "${vmContext.configuration}",
            "version": "$dartinoVersion",
            // TODO(sigurdm): Can we say something meaningful?
            "pid": 0,
            // TODO(sigurdm): Implement a startTime for devices with a clock.
            "startTime": 0,
            "isolates": isolates.map(isolateRef).toList()
          });
          break;
        case "getIsolate":
          String isolateIdString = decodedMessage["params"]["isolateId"];
          int isolateId = int.parse(
              isolateIdString.substring(isolateIdString.indexOf("/") + 1));

          sendResult({
            "type": "Isolate",
            "runnable": true,
            "livePorts": 0,
            "startTime": 0,
            "name": "Isolate $isolateId",
            "number": "$isolateId",
            // TODO(sigurdm): This seems to be required by the observatory.
            "_originNumber": "$isolateId",
            "breakpoints":
                state.vmContext.breakpoints().map(breakpointDesc).toList(),
            "rootLib": libraryRef(state.compiler.compiler.mainApp),
            "id": "$isolateIdString",
            "libraries": state.compiler.compiler.libraryLoader.libraries
                .map(libraryRef)
                .toList(),
            "pauseEvent": lastPauseEvent,
            // TODO(danrubel): determine proper values for these 2 entries
            "pauseOnExit": false,
            "exceptionPauseMode": "Unhandled",
            // Needed by observatory.
            "_debuggerSettings": {"_exceptions": "unhandled"},
          });
          break;
        case "addBreakpoint":
          String scriptId = decodedMessage["params"]["scriptId"];
          Uri uri = scripts[scriptId].script.resourceUri;
          int line = decodedMessage["params"]["line"];
          int column = decodedMessage["params"]["column"] ?? 1;
          // TODO(sigurdm): Use the isolateId.
          Breakpoint breakpoint =
              await state.vmContext.setFileBreakpoint(uri, line, column);
          if (breakpoint != null) {
            sendResult({
              "type": "Breakpoint",
              "id": "breakpoints/${breakpoint.id}",
              "breakpointNumber": breakpoint.id,
              "resolved": true,
              "location": locationDesc(
                  breakpoint.location(vmContext.debugState), false),
            });
          } else {
            sendError({"code": 102, "message": "Cannot add breakpoint"});
          }
          break;
        case "removeBreakpoint":
          String breakpointId = decodedMessage["params"]["breakpointId"];
          int id =
              int.parse(breakpointId.substring(breakpointId.indexOf("/") + 1));
          if (vmContext.isRunning || vmContext.isTerminated) {
            sendError({"code": 106, "message": "Isolate must be paused"});
            break;
          }
          Breakpoint breakpoint = await vmContext.deleteBreakpoint(id);
          if (breakpoint == null) {
            // TODO(sigurdm): Is this the right message?
            sendError({"code": 102, "message": "Cannot remove breakpoint"});
          } else {
            sendResult({"type": "Success"});
          }
          break;
        case "getObject":
          // TODO(sigurdm): should not be ignoring the isolate id.
          String id = decodedMessage["params"]["objectId"];
          int slashIndex = id.indexOf('/');
          switch (id.substring(0, slashIndex)) {
            case "libraries":
              String uri = id.substring(slashIndex + 1);
              sendResult(libraryDesc(state.compiler.compiler.libraryLoader
                  .lookupLibrary(Uri.parse(uri))));
              break;
            case "scripts":
              sendResult(scriptDesc(scripts[id]));
              break;
            case "functions":
              sendResult(functionDesc(vmContext.dartinoSystem.functionsById[
                  int.parse(id.substring(slashIndex + 1))]));
              break;
            case "objects":
              String path = id.substring(slashIndex + 1);
              List<int> dotted = path.split(".").map(int.parse).toList();
              int localFrame = dotted.first;
              int localSlot = dotted[1];
              List<int> fieldAccesses = dotted.skip(2).toList();
              RemoteObject remoteObject = await vmContext.processLocalStructure(
                  localFrame, localSlot,
                  fieldAccesses: fieldAccesses);
              sendResult(instanceDesc(remoteObject, id));
              break;
            default:
              throw "Unsupported object type $id";
          }
          break;
        case "getStack":
          String isolateIdString = decodedMessage["params"]["isolateId"];
          int isolateId = int.parse(
              isolateIdString.substring(isolateIdString.indexOf("/") + 1));
          BackTrace backTrace =
              await state.vmContext.backTrace(processId: isolateId);
          List frames = [];
          int index = 0;
          for (BackTraceFrame frame in backTrace.frames) {
            frames.add(await frameDesc(frame, index));
            index++;
          }

          sendResult({"type": "Stack", "frames": frames, "messages": [],});
          break;
        case "getSourceReport":
          String scriptId = decodedMessage["params"]["scriptId"];
          CompilationUnitElement compilationUnit = scripts[scriptId];
          Uri scriptUri = compilationUnit.script.file.uri;
          List<int> tokenTable = tokenTables[scriptUri];

          // We do not support coverage.
          assert(decodedMessage["params"]["reports"]
              .contains("PossibleBreakpoints"));
          int tokenPos = decodedMessage["params"]["tokenPos"] ?? 0;
          int endTokenPos =
              decodedMessage["params"]["endTokenPos"] ?? tokenTable.length - 1;
          int startPos = tokenTable[tokenPos];
          int endPos = tokenTable[endTokenPos];
          List<int> possibleBreakpoints = new List<int>();
          DartinoSystem system = state.compilationResults.last.system;
          for (FunctionElement function
              in FunctionsFinder.findNestedFunctions(compilationUnit)) {
            DartinoFunction dartinoFunction =
                system.functionsByElement[function];
            if (dartinoFunction == null) break;
            DebugInfo info = state.compiler
                .createDebugInfo(system.functionsByElement[function], system);
            if (info == null) break;
            for (SourceLocation location in info.locations) {
              // TODO(sigurdm): Investigate these.
              if (location == null || location.span == null) continue;
              int position = location.span.begin;
              if (!(position >= startPos && position <= endPos)) continue;
              possibleBreakpoints.add(binarySearch(tokenTable, position));
            }
          }
          Map range = {
            "scriptIndex": 0,
            "compiled": true,
            "startPos": tokenPos,
            "endPos": endTokenPos,
            "possibleBreakpoints": possibleBreakpoints,
            "callSites": [],
          };
          sendResult({
            "type": "SourceReport",
            "ranges": [range],
            "scripts": [scriptRef(scriptUri)],
          });
          break;
        case "resume":
          // TODO(sigurdm): use isolateId.
          String stepOption = decodedMessage["params"]["step"];
          switch (stepOption) {
            case "Into":
              // TODO(sigurdm): avoid needing await here.
              await vmContext.step();
              sendResult({"type": "Success"});
              break;
            case "Over":
              // TODO(sigurdm): avoid needing await here.
              await vmContext.stepOver();
              sendResult({"type": "Success"});
              break;
            case "Out":
              // TODO(sigurdm): avoid needing await here.
              await vmContext.stepOut();
              sendResult({"type": "Success"});
              break;
            case "OverAsyncSuspension":
              sendError({
                "code": 100,
                "message": "Feature is disabled",
                "data": {
                  "details":
                      "Stepping over async suspensions is not implemented",
                }
              });
              break;
            default:
              assert(stepOption == null);
              if (vmContext.isScheduled) {
                // TODO(sigurdm): Ensure other commands are not issued during
                // this.
                vmContext.cont();
              } else {
                vmContext.startRunning();
              }
              sendResult({"type": "Success"});
          }
          break;
        case "setExceptionPauseMode":
          // TODO(sigurdm): implement exception-pause-mode.
          sendResult({"type": "Success"});
          break;
        case "pause":
          await vmContext.interrupt();
          sendResult({"type": "Success"});
          break;
        case "addBreakpointWithScriptUri":
          // TODO(sigurdm): Use the isolateId.
          String scriptUri = decodedMessage["params"]["scriptUri"];
          int line = decodedMessage["params"]["line"] ?? 1;
          int column = decodedMessage["params"]["column"] ?? 1;
          if (vmContext.isRunning) {
            sendError({"code": 102, "message": "Cannot add breakpoint"});
            break;
          }
          Breakpoint breakpoint = await vmContext.setFileBreakpoint(
              Uri.parse(scriptUri), line, column);
          if (breakpoint == null) {
            sendError({"code": 102, "message": "Cannot add breakpoint"});
          } else {
            sendResult({
              "type": "Breakpoint",
              "id": "breakpoints/${breakpoint.id}",
              "breakpointNumber": breakpoint.id,
              "resolved": true,
              "location": locationDesc(
                  breakpoint.location(vmContext.debugState), false),
            });
          }
          break;
        default:
          sendError({
            "code": 100,
            "message": "Feature is disabled",
            "data": {
              "details":
                  "Request type ${decodedMessage["method"]} not implemented",
            }
          });
          if (logging) {
            print("Unhandled request type: ${decodedMessage["method"]}");
          }
      }
    }
  }

  void streamNotify(String streamId, Map event) {
    if (streams[streamId] ?? false) {
      send({
        "method": "streamNotify",
        "params": {"streamId": streamId, "event": event,},
        "jsonrpc": "2.0",
      });
    }
  }

  @override
  breakpointAdded(int processId, Breakpoint breakpoint) {
    streamNotify("Debug", {
      "type": "Event",
      "kind": "BreakpointAdded",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
      "breakpoint": breakpointDesc(breakpoint),
    });
  }

  @override
  breakpointRemoved(int processId, Breakpoint breakpoint) {
    streamNotify("Debug", {
      "type": "Event",
      "kind": "BreakpointRemoved",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
      "breakpoint": breakpointDesc(breakpoint),
    });
  }

  @override
  gc(int processId) {
    // TODO(sigurdm): Implement gc notification.
  }

  @override
  lostConnection() {
    socket.close();
  }

  @override
  pauseBreakpoint(
      int processId, BackTraceFrame topFrame, Breakpoint breakpoint) async {
    //TODO(danrubel): are there any other breakpoints
    // at which we are currently paused for a PauseBreakpoint event?
    List<Breakpoint> pauseBreakpoints = <Breakpoint>[];
    pauseBreakpoints.add(breakpoint);
    Map event = {
      "type": "Event",
      "kind": "PauseBreakpoint",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
      "topFrame": await frameDesc(topFrame, 0),
      "atAsyncSuspension": false,
      "breakpoint": breakpointDesc(breakpoint),
      "pauseBreakpoints":
          new List.from(pauseBreakpoints.map((bp) => breakpointDesc(bp))),
    };
    lastPauseEvent = event;
    streamNotify("Debug", event);
  }

  @override
  pauseException(
      int processId, BackTraceFrame topFrame, RemoteObject thrown) async {
    Map event = {
      "type": "Event",
      "kind": "PauseException",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
      "topFrame": await frameDesc(topFrame, 0),
      "atAsyncSuspension": false,
      // TODO(sigurdm): pass thrown as an instance.
    };
    streamNotify("Debug", event);
  }

  @override
  pauseExit(int processId, BackTraceFrame topFrame) {
    // TODO(sigurdm): implement pauseExit
  }

  @override
  pauseInterrupted(int processId, BackTraceFrame topFrame) async {
    Map event = {
      "type": "Event",
      "kind": "PauseInterrupted",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
      "topFrame": await frameDesc(topFrame, 0),
      "atAsyncSuspension": false,
    };
    lastPauseEvent = event;
    streamNotify("Debug", event);
  }

  @override
  pauseStart(int processId) {
    Map event = {
      "type": "Event",
      "kind": "PauseStart",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
    };
    lastPauseEvent = event;
    streamNotify("Debug", event);
  }

  @override
  processExit(int processId) {
    streamNotify("Isolate", {
      "type": "Event",
      "kind": "IsolateExit",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
    });
    socket.close();
  }

  @override
  processRunnable(int processId) {
    Map event = {
      "type": "Event",
      "kind": "IsolateRunnable",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
    };
    streamNotify("Isolate", event);
  }

  @override
  processStart(int processId) {
    streamNotify("Isolate", {
      "type": "Event",
      "kind": "IsolateStart",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  resume(int processId) async {
    Map event = {
      "type": "Event",
      "kind": "Resume",
      "isolate": isolateRef(processId),
      "timestamp": new DateTime.now().millisecondsSinceEpoch,
    };
    BackTraceFrame topFrame = vmContext.debugState.topFrame;
    if (topFrame != null) {
      event["topFrame"] = await frameDesc(vmContext.debugState.topFrame, 0);
    }
    lastPauseEvent = event;
    streamNotify("Debug", event);
  }

  @override
  writeStdErr(int processId, List<int> data) {
    Map event = {
      "type": "Event",
      "kind": "WriteEvent",
      "bytes": new String.fromCharCodes(data),
    };
    streamNotify("Stderr", event);
  }

  @override
  writeStdOut(int processId, List<int> data) {
    Map event = {
      "type": "Event",
      "kind": "WriteEvent",
      "bytes": new String.fromCharCodes(data),
    };
    streamNotify("Stdout", event);
  }

  @override
  terminated() {}
}

class FunctionsFinder extends BaseElementVisitor {
  final List<FunctionElement> result = new List<FunctionElement>();

  FunctionsFinder();

  static List<FunctionElement> findNestedFunctions(
      CompilationUnitElement element) {
    FunctionsFinder finder = new FunctionsFinder();
    finder.visit(element);
    return finder.result;
  }

  visit(Element e, [arg]) => e.accept(this, arg);

  visitElement(Element e, _) {}

  visitFunctionElement(FunctionElement element, _) {
    result.add(element);
    MemberElement memberContext = element.memberContext;
    if (memberContext == element) {
      memberContext.nestedClosures.forEach(visit);
    }
  }

  visitScopeContainerElement(ScopeContainerElement e, _) {
    e.forEachLocalMember(visit);
  }

  visitCompilationUnitElement(CompilationUnitElement e, _) {
    e.forEachLocalMember(visit);
  }
}
