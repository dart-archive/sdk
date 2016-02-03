// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.dartino;

import 'dart:dartino._system' as dartino;

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

  // We do not use an initializer for [_current] to ensure we can treeshake
  // the [Fiber] class.
  static Fiber _current;
  static Fiber _idleFibers;

  Fiber._initial() {
    _previous = this;
    _next = this;
  }

  Fiber._forked(entry) {
    current;  // Force initialization of fiber sub-system.
    _coroutine = new Coroutine((ignore) {
      dartino.runToEnd(entry);
    });
  }

  static Fiber get current {
    var current = _current;
    if (current != null) return current;
    return _current = new Fiber._initial();
  }

  static Fiber fork(entry) {
    Fiber fiber = new Fiber._forked(entry);
    _markReady(fiber);
    return fiber;
  }

  static void yield() {
    // Handle messages so that fibers that are blocked on receiving
    // messages can wake up.
    Process._handleMessages();
    _current._coroutine = Coroutine._coroutineCurrent();
    _schedule(_current._next);
  }

  static void exit([value]) {
    // If we never created a fiber, we can just go ahead and halt now.
    if (_current == null) dartino.halt();

    _current._exit(value);
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
    _schedule(next);
    return _result;
  }

  void _exit(value) {
    Fiber fiber = this;
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
    _schedule(next);
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
    if (exiting && _idleFibers == null) dartino.halt();

    while (true) {
      Process._handleMessages();
      // A call to _handleMessages can handle more messages than signaled, so
      // we can get a following false-positive wakeup. If no new _current is
      // set, simply yield again.
      current = _current;
      if (current != null) return current;
      dartino.yield(dartino.InterruptKind.yield.index);
    }
  }

  static void _yieldTo(Fiber from, Fiber to) {
    from._coroutine = Coroutine._coroutineCurrent();
    _schedule(to);
  }

  // TODO(kasperl): This is temporary debugging support. We
  // should probably replace this support for passing in an
  // id of some sort when forking a fiber.
  static int _count = 0;
  int _index = _count++;
  toString() => "fiber:$_index";

  static void _schedule(Fiber to) {
    _current = to;
    dartino.coroutineChange(to._coroutine, null);
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
    var result = dartino.coroutineChange(this, argument);

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
    return dartino.coroutineChange(caller, value);
  }

  _coroutineStart(entry) {
    // The first call to changeStack is actually skipped but we need
    // it to make sure the newly started coroutine is suspended in
    // exactly the same way as we do when yielding.
    var argument = dartino.coroutineChange(0, 0);
    var result = entry(argument);

    // Mark this coroutine as done and change back to the caller.
    Coroutine caller = _caller;
    _caller = this;
    dartino.coroutineChange(caller, result);
  }

  @dartino.native external static _coroutineCurrent();
  @dartino.native external static _coroutineNewStack(coroutine, entry);
}

class ProcessDeath {
  final Process process;
  final int _reason;

  ProcessDeath._(this.process, this._reason);

  DeathReason get reason => DeathReason.values[_reason];
}

// TODO: Keep these in sync with src/vm/process.h:Signal::Kind
enum DeathReason {
  CompileTimeError,
  Terminated,
  UncaughtException,
  UnhandledSignal,
  Killed,
}

class Process {
  // This is the address of the native process/4 so that it fits in a Smi.
  final int _nativeProcessHandle;

  bool operator==(other) {
    return
        other is Process &&
        other._nativeProcessHandle == _nativeProcessHandle;
  }

  int get hashCode => _nativeProcessHandle.hashCode;

  @dartino.native bool link() {
    throw dartino.nativeError;
  }

  @dartino.native void unlink() {
    switch (dartino.nativeError) {
      case dartino.wrongArgumentType:
        throw new StateError("Cannot unlink from parent process.");
      default:
        throw dartino.nativeError;
    }
  }

  @dartino.native bool monitor(Port port) {
    switch (dartino.nativeError) {
      case dartino.wrongArgumentType:
        throw new StateError("The argument to monitor must be a Port object.");
      default:
        throw dartino.nativeError;
    }
  }

  @dartino.native void unmonitor(Port port) {
    switch (dartino.nativeError) {
      case dartino.wrongArgumentType:
        throw new StateError(
            "The argument to unmonitor must be a Port object.");
      default:
        throw dartino.nativeError;
    }
  }

  @dartino.native void kill() {
    throw dartino.nativeError;
  }

  static Process spawn(Function fn, [argument]) {
    if (!isImmutable(fn)) {
      throw new ArgumentError(
          'The closure passed to Process.spawn() must be immutable.');
    }

    if (!isImmutable(argument)) {
      throw new ArgumentError(
          'The optional argument passed to Process.spawn() must be immutable.');
    }

    return _spawn(_entry, fn, argument, true, true, null);
  }

  static Process spawnDetached(Function fn, {Port monitor}) {
    if (!isImmutable(fn)) {
      throw new ArgumentError(
          'The closure passed to Process.spawnDetached() must be immutable.');
    }

    return _spawn(_entry, fn, null, true, false, monitor);
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
    if (fn == null) {
      throw new ArgumentError.notNull("fn");
    }
    if (!isImmutable(fn)) {
      throw new ArgumentError.value(
          fn, "fn", "Closure passed to Process.divide must be immutable.");
    }
    if (arguments == null) {
      throw new ArgumentError.notNull("arguments");
    }

    int length = arguments.length;
    for (int i = 0; i < length; i++) {
      if (!isImmutable(arguments[i])) {
        throw new ArgumentError.value(
            arguments[i], "@$i",
            "Cannot pass mutable arguments to subprocess via Process.divide.");
      }
    }

    List channels = new List(length);
    for (int i = 0; i < length; i++) {
      channels[i] = new Channel();

      final argument = arguments[i];
      final port = new Port(channels[i]);
      Process.spawnDetached(() {
        try {
          Process.exit(value: fn(argument), to: port);
        } finally {
          // TODO(kustermann): Handle error properly. Once we do this, we can
          // remove the 'fn == null' check above.
          Process.exit(to: port);
        }
      });
    }
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
      dartino.yield(dartino.InterruptKind.terminate.index);
    }
  }

  // Low-level entry for spawned processes.
  static void _entry(fn, argument) {
    if (argument == null) {
      dartino.runToEnd(fn);
    } else {
      dartino.runToEnd(() => fn(argument));
    }
  }

  // Low-level helper function for spawning.
  @dartino.native static Process _spawn(Function entry,
                                       Function fn,
                                       argument,
                                       bool linkToChild,
                                       bool linkFromChild,
                                       Port monitor) {
    throw new ArgumentError();
  }

  static void _handleMessages() {
    Channel channel;
    while ((channel = _queueGetChannel()) != null) {
      var message = _queueGetMessage();
      if (message is ProcessDeath) {
        message = _queueSetupProcessDeath(message);
      }
      channel.send(message);
    }
  }

  @dartino.native external static Process get current;
  @dartino.native external static _queueGetMessage();
  @dartino.native external static _queueSetupProcessDeath(ProcessDeath message);
  @dartino.native external static Channel _queueGetChannel();
}

// Ports allow you to send messages to a channel. Ports are
// are transferable and can be sent between processes.
class Port {
  // A Smi stores the aligned pointer to the C++ port object.
  final int _port;

  factory Port(Channel channel) {
    return Port._create(channel);
  }

  // TODO(kasperl): Temporary debugging aid.
  int get id => _port;

  // Send a message to the channel. Not blocking.
  @dartino.native void send(message) {
    switch (dartino.nativeError) {
      case dartino.wrongArgumentType:
        throw new ArgumentError();
      case dartino.illegalState:
        throw new StateError("Port is closed.");
      default:
        throw dartino.nativeError;
    }
  }

  @dartino.native void _sendExit(value) {
    throw new StateError("Port is closed.");
  }

  @dartino.native external static Port _create(Channel channel);
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
    Fiber sender = Fiber.current;
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
      Fiber receiver = Fiber.current;
      _receiver = receiver;
      Fiber next = Fiber._suspendFiber(receiver, false);
      Fiber._yieldTo(receiver, next);
    }

    return _dequeue();
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

@dartino.native external bool _isImmutable(String string);

/// Returns a channel that will receive a message in [milliseconds]
/// milliseconds.
// TODO(sigurdm): Move this function?
Channel sleep(int milliseconds) {
  if (milliseconds is! int) throw new ArgumentError(milliseconds);
  Channel channel = new Channel();
  Port port = new Port(channel);
  _sleep(milliseconds, port);
  return channel;
}

@dartino.native external void _sleep(int milliseconds, Port port);
