// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';
import 'package:immutable/immutable.dart';

const List API = const [
  const RpcMethod('foo', arity: 0),
  const RpcMethod('bar', arity: 0),
  const RpcMethod('baz', arity: 1),
  const RpcMethod('biz', arity: 1),
];

class Server extends RpcServer {
  Server._internal() : super(API) {
    this['foo'] = foo;
    this['bar'] = bar;
    this['baz'] = baz;
    this['biz'] = biz;
  }

  foo() => 42;
  bar() => 87;
  baz(x) => x;
  biz(x) => throw x;

  static Port spawn() => RpcServer.spawn(_create);
  static Server _create() => new Server._internal();
}

class Client extends RpcClient {
  Client(Port port) : super(API, port);

  Function get foo => this['foo'];
  Function get bar => this['bar'];
  Function get baz => this['baz'];
  Function get biz => this['biz'];
}

main() {
  Client client = new Client(Server.spawn());

  // TODO(kasperl): Allow calling these functions without
  // wrapping all the calls in parenthesis.
  Expect.equals(42, (client.foo)());
  Expect.equals(87, (client.bar)());

  Expect.equals(55, (client.baz)(55));
  Expect.equals(99, (client.baz)(99));

  Expect.throws(() => (client.baz)(client), (e) => e is ArgumentError);

  Expect.throws(() => (client.biz)(1), (e) => e == 1);
  Expect.throws(() => (client.biz)(2), (e) => e == 2);

  client.done();
}


// --------------------------------------------------------------------------

// This is a very basic RPC client/server implementation.
// The intention is to try to improve the functionality
// of the underlying platform to a point where it's easy
// to implement these kinds of abstractions reliably.
class RpcMethod {
  final String name;
  final int arity;
  const RpcMethod(this.name, {this.arity: 0});
}

class RpcServer {
  final Channel _channel = new Channel();

  final List _api;
  final List _functions;
  final Map _opcodes = new Map<String, int>();

  RpcServer(List api) : _api = api, _functions = new List(api.length) {
    for (int i = 0; i < api.length; i++) {
      _opcodes[api[i].name] = i;
    }
  }

  Port get port => new Port(_channel);

  void operator[]=(String name, Function function) {
    int opcode = _opcodes[name];
    if (opcode == null) {
      throw "Server cannot implement '$name' which is not part of its API.";
    }
    _functions[opcode] = function;
  }

  void start() {
    for (int i = 0; i < _api.length; i++) {
      if (_functions[i] == null) {
        String name = _api[i].name;
        throw "Server does not implement '$name' which is part of its API.";
      }
    }
    Fiber.fork(_processMessages);
  }

  void _processMessages() {
    while (true) {
      LinkedList command = _channel.receive();
      int opcode = command.head;
      if (opcode == -1) return;
      Port replyTo = command.tail.head;
      int arity = _api[opcode].arity;
      int args = command.length - 2;
      if (args != arity) throw "Bad arity";

      LinkedList arguments = command.tail.tail;
      try {
        Function function = _functions[opcode];
        var result;
        switch (arity) {
          case 0: result = function(); break;
          case 1: result = function(arguments.head); break;
          case 2: result = function(arguments.head, arguments.tail.head); break;
          default: throw "Too many arguments.";
        }
        replyTo.send(new LinkedList.fromList([0, result]));
      } catch (e) {
        replyTo.send(new LinkedList.fromList([1, e]));
      }
    }
  }

  static Port spawn(RpcServer create()) {
    Channel channel = new Channel();
    Port initPort = new Port(channel);
    Process.spawnDetached(() => _runNewServer(initPort));
    Port port = channel.receive();
    port.send(create);
    return channel.receive();
  }

  static void _runNewServer(Port port) {
    Channel channel = new Channel();
    port.send(new Port(channel));
    Function create = channel.receive();
    RpcServer server = create();
    server.start();
    port.send(server.port);
  }
}

class RpcClient {
  final Port _port;
  final Map<String, Function> _api = new Map<String, Function>();

  RpcClient(List api, this._port) {
    List stubs = [ _newStub0, _newStub1, _newStub2 ];
    for (int i = 0; i < api.length; i++) {
      RpcMethod method = api[i];
      Function stub = stubs[method.arity];
      _api[method.name] = stub(i);
    }
  }

  Function operator[](String name) => _api[name];

  Function _newStub0(int opcode) => () {
    return _forward([opcode, null]);
  };

  Function _newStub1(int opcode) => (a0) {
    return _forward([opcode, null, a0]);
  };

  Function _newStub2(int opcode) => (a0, a1) {
    return _forward([opcode, null, a0, a1]);
  };

  void done() {
    _port.send(new LinkedList(-1, null));
  }

  _forward(List command) {
    Channel replyTo = new Channel();
    command[1] = new Port(replyTo);
    _port.send(new LinkedList.fromList(command));
    LinkedList reply = replyTo.receive();
    var tag = reply.head;
    var result = reply.tail.head;
    if (tag == 1) throw result;
    return result;
  }
}
