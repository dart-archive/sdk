// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.fletch;

import 'dart:_fletch_system' as fletch;

/// Fibers are lightweight co-operative multitask units of execution. They
/// are scheduled on top of OS-level threads, but they are cheap to create
/// and block.
class Fiber {

  // We keep track of the top of the coroutine stack and
  // the list of other fibers that are waiting for this
  // fiber to exit.
  Coroutine _coroutine;
  List<Fiber> _joiners;

  // When a fiber exits, we keep the result of running
  // its code around so we can return to other fibers
  // that join it.
  bool _isDone = false;
  var _result;

  // The ready fibers are linked together.
  Fiber _previous;
  Fiber _next;

  static Fiber _current = new Fiber._initial();
  static Fiber _idleFibers;

  // This static is initialized as part of creating the
  // initial fiber. This way we can avoid checking for
  // lazy initialization for it.
  static Coroutine _scheduler;

  Fiber._initial() {
    _previous = this;
    _next = this;
    _scheduler = new Coroutine(_schedulerLoop);
  }

  Fiber._forked(entry) {
    _coroutine = new Coroutine((ignore) {
      fletch.runToEnd(entry);
    });
  }

  static Fiber get current => _current;

  static Fiber fork(entry) {
    _current;  // Force initialization of fiber sub-system.
    Fiber fiber = new Fiber._forked(entry);
    _markReady(fiber);
    return fiber;
  }

  static void yield() {
    // Handle messages so that fibers that are blocked on receiving
    // messages can wake up.
    Process._handleMessages();
    _current._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(_scheduler, _current._next);
  }

  static void exit([value]) {
    // If we never needed the scheduler coroutine, we can just
    // go ahead and halt now.
    if (_scheduler == null) fletch.halt();

    Fiber fiber = _current;
    List<Fiber> joiners = fiber._joiners;
    if (joiners != null) {
      for (Fiber joiner in joiners) _resumeFiber(joiner);
      joiners.clear();
    }

    fiber._isDone = true;
    fiber._result = value;

    // Suspend the current fiber. It will never wake up again.
    Fiber next = _suspendFiber(fiber, true);
    fiber._coroutine = null;
    fletch.coroutineChange(Fiber._scheduler, next);
  }

  join() {
    // If the fiber is already done, we just return the result.
    if (_isDone) return _result;

    // Add the current fiber to the list of fibers waiting
    // to join [this] fiber.
    Fiber fiber = _current;
    if (_joiners == null) {
      _joiners = [ fiber ];
    } else {
      _joiners.add(fiber);
    }

    // Suspend the current fiber and change to the scheduler.
    // When we get back, the [this] fiber has exited and we
    // can go ahead and return the result.
    Fiber next = _suspendFiber(fiber, false);
    fiber._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(Fiber._scheduler, next);
    return _result;
  }

  static void _resumeFiber(Fiber fiber) {
    _idleFibers = _unlink(fiber);
    _markReady(fiber);
  }

  static void _markReady(Fiber fiber) {
    _current = _link(fiber, _current);
  }

  static Fiber _link(Fiber fiber, Fiber list) {
    if (list == null) {
      fiber._next = fiber;
      fiber._previous = fiber;
      return fiber;
    }

    Fiber next = list._next;
    list._next = fiber;
    next._previous = fiber;
    fiber._previous = list;
    fiber._next = next;
    return list;
  }

  static Fiber _unlink(Fiber fiber) {
    Fiber next = fiber._next;
    if (identical(fiber, next)) {
      return null;
    }

    Fiber previous = fiber._previous;
    previous._next = next;
    next._previous = previous;
    return next;
  }

  static Fiber _suspendFiber(Fiber fiber, bool exiting) {
    Fiber current = _current = _unlink(fiber);

    if (exiting) {
      fiber._next = null;
      fiber._previous = null;
    } else {
      _idleFibers = _link(fiber, _idleFibers);
    }

    if (current != null) return current;

    // If we don't have any idle fibers, halt.
    if (exiting && _idleFibers == null) fletch.halt();

    while (true) {
      Process._handleMessages();
      // A call to _handleMessages can handle more messages than signaled, so
      // we can get a following false-positive wakeup. If no new _current is
      // set, simply yield again.
      current = _current;
      if (current != null) return current;
      fletch.yield(fletch.InterruptKind.yield.index);
    }
  }

  static void _yieldTo(Fiber from, Fiber to) {
    from._coroutine = Coroutine._coroutineCurrent();
    fletch.coroutineChange(_scheduler, to);
  }

  // TODO(kasperl): This is temporary debugging support. We
  // should probably replace this support for passing in an
  // id of some sort when forking a fiber.
  static int _count = 0;
  int _index = _count++;
  toString() => "fiber:$_index";

  // TODO(kasperl): Right now, we ignore the events -- and they
  // are always null -- but it is easy to imagine using the
  // events to communicate things to the scheduler.
  static void _schedulerLoop(next) {
    while (true) {
      // Update the current fiber to the next one and change to
      // its coroutine. In return, the scheduled fiber determines
      // which fiber to schedule next.
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
  static void spawn(Function fn, [argument]) {
    if (!isImmutable(fn)) {
      throw new ArgumentError(
          'The closure passed to Process.spawn() must be immutable.');
    }

    if (!isImmutable(argument)) {
      throw new ArgumentError(
          'The optional argument passed to Process.spawn() must be immutable.');
    }

    _spawn(_entry, fn, argument);
  }

  /**
   * Divide the elements in [arguments] into a matching number of processes
   * with [fn] as entry. The current process blocks until all processes have
   * terminated.
   *
   * The elements in [arguments] can be any immutable (see [isImmutable])
   * object.
   *
   * The function [fn] must be a top-level or static function.
   */
  static List divide(fn(argument), List arguments) {
    // TODO(ajohnsen): Type check arguments.
    int length = arguments.length;
    List channels = new List(length);
    for (int i = 0; i < length; i++) {
      channels[i] = new Channel();
    }
    _divide(_entryDivide, fn, channels, arguments);
    for (int i = 0; i < length; i++) {
      channels[i] = channels[i].receive();
    }
    return channels;
  }

  /**
   * Exit the current process. If a non-null [to] port is provided,
   * the process will send the provided [value] to the [to] port as
   * its final action.
   */
  static void exit({value, Port to}) {
    try {
      if (to != null) to._sendExit(value);
    } finally {
      fletch.yield(fletch.InterruptKind.terminate.index);
    }
  }

  // Low-level entry for spawned processes.
  static void _entry(fn, argument) {
    if (argument == null) {
      fletch.runToEnd(fn);
    } else {
      fletch.runToEnd(() => fn(argument));
    }
  }

  // Low-level helper function for spawning.
  @fletch.native static void _spawn(Function entry, Function fn, argument) {
    throw new ArgumentError();
  }

  // Low-level entry for dividing processes.
  static void _entryDivide(fn, port, argument) {
    try {
      Process.exit(value: fn(argument), to: port);
    } finally {
      // TODO(ajohnsen): Handle exceptions?
      Process.exit(to: port);
    }
  }

  // Low-level helper function for dividing.
  @fletch.native static _divide(
      Function entry,
      Function fn,
      List<Port> ports,
      List arguments) {
    for (int i = 0; i < arguments.length; i++) {
      if (!isImmutable(arguments[i])) {
        throw new ArgumentError.value(
            arguments[i], "@$i", "Cannot pass mutable data");
      }
    }
    throw new ArgumentError.value(fn, "fn", "Entry function must be static");
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
  final int _port;

  factory Port(Channel channel) {
    return Port._create(channel);
  }

  const Port._(this._port);

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

  @fletch.native void _sendExit(value) {
    throw new StateError("Port is closed.");
  }

  @fletch.native external static Port _create(Channel channel);
  @fletch.native external static void _incrementRef(int port);
}

class Channel {
  Fiber _receiver;  // TODO(kasperl): Should this be a queue too?

  // TODO(kasperl): Maybe make this a bit smarter and store
  // the elements in a growable list? Consider allowing bounds
  // on the queue size.
  _ChannelEntry _head;
  _ChannelEntry _tail;

  // Deliver the message synchronously. If the receiver
  // isn't ready to receive yet, the sender blocks.
  void deliver(message) {
    Fiber sender = Fiber._current;
    _enqueue(new _ChannelEntry(message, sender));
    Fiber next = Fiber._suspendFiber(sender, false);
    // TODO(kasperl): Should we yield to receiver if possible?
    Fiber._yieldTo(sender, next);
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
      Fiber receiver = Fiber._current;
      _receiver = receiver;
      Fiber next = Fiber._suspendFiber(receiver, false);
      Fiber._yieldTo(receiver, next);
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
    Fiber receiver = _receiver;
    if (receiver != null) {
      _receiver = null;
      Fiber._resumeFiber(receiver);
    }
  }

  _dequeue() {
    _ChannelEntry entry = _head;
    _ChannelEntry next = entry.next;
    _head = next;
    if (next == null) _tail = next;
    Fiber sender = entry.sender;
    if (sender != null) Fiber._resumeFiber(sender);
    return entry.message;
  }
}

class _ChannelEntry {
  final message;
  final Fiber sender;
  _ChannelEntry next;
  _ChannelEntry(this.message, this.sender);
}

bool isImmutable(Object object) => _isImmutable(object);

@fletch.native external bool _isImmutable(String string);
