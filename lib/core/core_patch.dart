// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;

const patch = "patch";

@patch bool identical(Object a, Object b) {
  return false;
}

@patch class Object {
  @patch String toString() => '[object Object]';

  // TODO(ajohnsen): Not very good..
  @patch int get hashCode => 42;

  @patch noSuchMethod(Invocation invocation) {
    // TODO(kasperl): Extract information from the invocation
    // so we can construct the right NoSuchMethodError.
    fletch.unresolved("<unknown>");
  }

  // The noSuchMethod helper is automatically called from the
  // trampoline and it is passed the selector. The arguments
  // to the original call are still present on the stack, so
  // it is possible to dig them out if need be.
  _noSuchMethod(selector) => noSuchMethod(null);

  // The noSuchMethod trampoline is automatically generated
  // by the compiler. It calls the noSuchMethod helper and
  // takes care off removing an arbitrary number of arguments
  // from the caller stack before it returns.
  external _noSuchMethodTrampoline();
}

// TODO(ajohnsen): Merge 'fletch.String' into this String.
@patch class String {
  @patch factory String.fromCharCodes(
      Iterable<int> charCode,
      [int start = 0,
       int end]) {
    return fletch.String.fromCharCodes(charCode, start, end);
  }

  @patch factory String.fromCharCode(int charCode) {
    return fletch.String.fromCharCode(charCode);
  }
}

@patch class StringBuffer {
  String _buffer;

  @patch StringBuffer([this._buffer = ""]);

  @patch void write(Object obj) {
    _buffer = _buffer + "$obj";
  }

  @patch void writeCharCode(int charCode) {
    _buffer = _buffer + new String.fromCharCode(charCode);
  }

  @patch void clear() {
    _buffer = "";
  }

  @patch int get length => _buffer.length;

  @patch String toString() => _buffer;
}

@patch class Error {
  @patch static String _stringToSafeString(String string) {
    throw "_stringToSafeString is unimplemented";
  }

  @patch static String _objectToString(Object object) {
    throw "_stringToSafeString is unimplemented";
  }

  @patch StackTrace get stackTrace {
    throw "getter stackTrace is unimplemented";
  }
}

@patch class Stopwatch {
  @patch @fletch.native external static int _now();

  @patch static int _initTicker() {
    _frequency = _fletchNative_frequency();
  }

  @fletch.native external static int _fletchNative_frequency();
}

@patch class List {
  @patch factory List([int length]) {
    return fletch.newList(length);
  }

  @patch factory List.from(Iterable elements, {bool growable: true}) {
    // TODO(ajohnsen): elements.length can be slow if not a List. Consider
    // fast-path non-list & growable, and create internal helper for non-list &
    // non-growable.
    int length = elements.length;
    var list;
    if (growable) {
      list = fletch.newList(null);
      list.length = length;
    } else {
      list = fletch.newList(length);
    }
    if (elements is List) {
      for (int i = 0; i < length; i++) {
        list[i] = elements[i];
      }
    } else {
      int i = 0;
      elements.forEach((e) { list[i++] = e; });
    }
    return list;
  }
}

@patch class NoSuchMethodError {
  @patch String toString() {
    return "NoSuchMethodError: '$_memberName'";
  }
}

@patch class Null {
  // This function is overridden, so we can bypass the 'this == null' check.
  bool operator ==(other) => other == null;
}

@patch class int {
  @patch static int parse(
      String source,
      {int radix: 0,
       int onError(String source)}) {
    return _parse(source, radix);
  }

  @fletch.native static _parse(String source, int radix) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError(source);
      case fletch.indexOutOfBounds:
        throw new FormatException("Can't parse to an integer", source);
    }
  }
}

@patch class double {
  @patch static double parse(String source, [double onError(String source)]) {
    throw new UnimplementedError("double.parse");
  }
}

class Thread {

  // We keep track of the top of the coroutine stack and
  // the list of other threads that are waiting for this
  // thread to exit.
  Coroutine _coroutine;
  List<Thread> _joiners;

  // When a thread exits, we keep the result of running
  // its code around so we can return to other threads
  // that join it.
  bool _isDone = false;
  var _result;

  // The ready threads are linked together.
  Thread _previous;
  Thread _next;

  static Thread _current = new Thread._initial();
  static int _threadCount = 1;

  // This static is initialized as part of creating the
  // initial thread. This way we can avoid checking for
  // lazy initialization for it.
  static Coroutine _scheduler;

  Thread._initial() {
    _previous = this;
    _next = this;
    _scheduler = new Coroutine(_schedulerLoop);
  }

  Thread._forked(entry) {
    _coroutine = new Coroutine((ignore) {
      fletch.runToEnd(entry);
    });
  }

  static Thread get current => _current;

  static Thread fork(entry) {
    _current;  // Force initialization of threading system.
    Thread thread = new Thread._forked(entry);
    _threadCount++;
    _resumeThread(thread);
    return thread;
  }

  static void yield() {
    _current._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(_scheduler, _current._next);
  }

  static void exit([value]) {
    // If we never needed the scheduler coroutine, we can just
    // go ahead and halt now.
    if (_scheduler == null) fletch.halt(0);

    Thread thread = _current;
    List<Thread> joiners = thread._joiners;
    if (joiners != null) {
      for (Thread joiner in joiners) _resumeThread(joiner);
      joiners.clear();
    }

    _threadCount--;
    thread._isDone = true;
    thread._result = value;

    // Suspend the current thread. It will never wake up again.
    Thread next = _suspendThread(thread);
    thread._coroutine = null;
    fletch.coroutineChange(Thread._scheduler, next);
  }

  join() {
    // If the thread is already done, we just return the result.
    if (_isDone) return _result;

    // Add the current thread to the list of threads waiting
    // to join [this] thread.
    Thread thread = _current;
    if (_joiners == null) {
      _joiners = [ thread ];
    } else {
      _joiners.add(thread);
    }

    // Suspend the current thread and change to the scheduler.
    // When we get back, the [this] thread has exited and we
    // can go ahead and return the result.
    Thread next = _suspendThread(thread);
    thread._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(Thread._scheduler, next);
    return _result;
  }

  static void _resumeThread(Thread thread) {
    Thread current = _current;
    if (current == null) {
      thread._next = thread;
      thread._previous = thread;
      _current = thread;
    } else {
      Thread next = current._next;
      current._next = thread;
      next._previous = thread;
      thread._previous = current;
      thread._next = next;
    }
  }

  static Thread _suspendThread(Thread thread) {
    Thread previous = thread._previous;
    if (identical(previous, thread)) {
      // If no more threads are alive, the process is done.
      if (_threadCount == 0) fletch.halt(0);
      _current = null;
      thread._previous = null;
      thread._next = null;
      while (true) {
        Process._handleMessages();
        // A call to _handleMessages can handle more messages than signaled, so
        // we can get a following false-positive wakeup. If no new _current is
        // set, simply yield again.
        thread = _current;
        if (thread != null) return thread;
        fletch.yield(false);
      }
    } else {
      Thread next = thread._next;
      previous._next = next;
      next._previous = previous;
      thread._next = null;
      thread._previous = null;
      return next;
    }
  }

  static void _yieldTo(Thread from, Thread to) {
    from._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(_scheduler, to);
  }

  // TODO(kasperl): This is temporary debugging support. We
  // should probably replace this support for passing in an
  // id of some sort when forking a thread.
  static int _count = 0;
  int _index = _count++;
  toString() => "thread:$_index";

  // TODO(kasperl): Right now, we ignore the events -- and they
  // are always null -- but it is easy to imagine using the
  // events to communicate things to the scheduler.
  static void _schedulerLoop(next) {
    while (true) {
      // Update the current thread to the next one and change to
      // its coroutine. In return, the scheduled thread determines
      // which thread to schedule next.
      _current = next;
      next = fletch.coroutineChange(next._coroutine, null);
    }
  }
}

class Coroutine {

  // TODO(kasperl): The VM has assumptions about the layout
  // of coroutine fields. We should validate that the code
  // agrees with those assumptions.
  var _stack;
  var _caller;

  Coroutine(entry) {
    _stack = _coroutineNewStack(this, entry);
  }

  bool get isSuspended => identical(_caller, null);
  bool get isRunning => !isSuspended && !isDone;
  bool get isDone => identical(_caller, this);

  call(argument) {
    if (!isSuspended) throw "Cannot call non-suspended coroutine";
    _caller = _coroutineCurrent();
    var result = fletch.coroutineChange(this, argument);

    // If the called coroutine is done now, we clear the
    // stack reference in it so the memory can be reclaimed.
    if (isDone) {
      _stack = null;
    } else {
      _caller = null;
    }
    return result;
  }

  static yield(value) {
    Coroutine caller = _coroutineCurrent()._caller;
    if (caller == null) throw "Cannot yield outside coroutine";
    return fletch.coroutineChange(caller, value);
  }

  _coroutineStart(entry) {
    // The first call to changeStack is actually skipped but we need
    // it to make sure the newly started coroutine is suspended in
    // exactly the same way as we do when yielding.
    var argument = fletch.coroutineChange(0, 0);
    var result = entry(argument);

    // Mark this coroutine as done and change back to the caller.
    Coroutine caller = _caller;
    _caller = this;
    fletch.coroutineChange(caller, result);
  }

  @fletch.native external static _coroutineCurrent();
  @fletch.native external static _coroutineNewStack(coroutine, entry);
}

class Process {
  /**
   * Spawn a top-level function.
   */
  static spawn(Function fn, [argument]) => _spawn(_entry, fn, argument);

  // Low-level entry for spawned processes.
  static void _entry(fn, argument) {
    if (argument == null) {
      fletch.runToEnd(fn);
    } else {
      fletch.runToEnd(() => fn(argument));
    }
  }

  // Low-level helper function for spawning.
  @fletch.native static _spawn(Function entry, Function fn, argument) {
    throw new ArgumentError();
  }

  static void _handleMessages() {
    Channel channel;
    while ((channel = _queueGetChannel()) != null) {
      var message = _queueGetMessage();
      channel.send(message);
    }
  }

  @fletch.native external static _queueGetMessage();
  @fletch.native external static Channel _queueGetChannel();
}

// The port list sentinel is sent as a prefix to the sequence
// of messages sent using [Port.sendMultiple].
class _PortListSentinel {
  const _PortListSentinel();
}

const _portListSentinel = const _PortListSentinel();

// Ports allow you to send messages to a channel. Ports are
// are transferable and can be sent between processes.
class Port {
  int _port;
  Port(Channel channel) {
    _port = _create(channel, this);
  }

  // TODO(kasperl): Temporary debugging aid.
  int get id => _port;

  // Send a message to the channel. Not blocking.
  @fletch.native void send(message) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError();
      case fletch.illegalState:
        throw new StateError("Port is closed.");
      default:
        throw fletch.nativeError;
    }
  }

  // Send multiple messages to the channel. Not blocking.
  void sendMultiple(Iterable iterable) {
    _sendList(iterable.toList(growable: true), _portListSentinel);
  }

  @fletch.native void _sendList(List list, sentinel) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError();
      case fletch.illegalState:
        throw new StateError("Port is closed.");
      default:
        throw fletch.nativeError;
    }
  }

  // Close the port. Messages already sent to a port will still
  // be delivered to the corresponding channel.
  void close() {
    int port = _port;
    if (port == 0) throw new StateError("Port already closed.");
    _port = 0;
    _close(port, this);
  }

  @fletch.native external static int _create(Channel channel, Port port);
  @fletch.native external static void _close(int port, Port port);
  @fletch.native external static void _incrementRef(int port);
}

class Channel {
  Thread _receiver;  // TODO(kasperl): Should this be a queue too?

  // TODO(kasperl): Maybe make this a bit smarter and store
  // the elements in a growable list? Consider allowing bounds
  // on the queue size.
  _ChannelEntry _head;
  _ChannelEntry _tail;

  // Deliver the message synchronously. If the receiver
  // isn't ready to receive yet, the sender blocks.
  void deliver(message) {
    Thread sender = Thread._current;
    _enqueue(new _ChannelEntry(message, sender));
    Thread next = Thread._suspendThread(sender);
    // TODO(kasperl): Should we yield to receiver if possible?
    Thread._yieldTo(sender, next);
  }

  // Send a message to the channel. Not blocking.
  void send(message) {
    _enqueue(new _ChannelEntry(message, null));
  }

  // Receive a message. If no messages are available
  // the receiver blocks.
  receive() {
    if (_receiver != null) {
      throw new StateError("Channel cannot have multiple receivers (yet).");
    }

    if (_head == null) {
      Thread receiver = Thread._current;
      _receiver = receiver;
      Thread next = Thread._suspendThread(receiver);
      Thread._yieldTo(receiver, next);
    }

    var result = _dequeue();
    if (identical(result, _portListSentinel)) {
      int length = _dequeue();
      result = new List(length);
      for (int i = 0; i < length; i++) result[i] = _dequeue();
    }
    return result;
  }

  _enqueue(_ChannelEntry entry) {
    if (_tail == null) {
      _head = _tail = entry;
    } else {
      _tail = _tail.next = entry;
    }

    // Signal the receiver (if any).
    Thread receiver = _receiver;
    if (receiver != null) {
      _receiver = null;
      Thread._resumeThread(receiver);
    }
  }

  _dequeue() {
    _ChannelEntry entry = _head;
    _ChannelEntry next = entry.next;
    _head = next;
    if (next == null) _tail = next;
    Thread sender = entry.sender;
    if (sender != null) Thread._resumeThread(sender);
    return entry.message;
  }
}

class _ChannelEntry {
  final message;
  final Thread sender;
  _ChannelEntry next;
  _ChannelEntry(this.message, this.sender);
}
