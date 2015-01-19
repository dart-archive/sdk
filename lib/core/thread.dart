// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

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
      _runToEnd(entry);
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
    Coroutine._coroutineChange(_scheduler, _current._next);
  }

  static void exit([value]) {
    // If we never needed the scheduler coroutine, we can just
    // go ahead and halt now.
    if (_scheduler == null) _halt(0);

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
    Coroutine._coroutineChange(Thread._scheduler, next);
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
    Coroutine._coroutineChange(Thread._scheduler, next);
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
      if (_threadCount == 0) _halt(0);
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
        _processYield();
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
    Coroutine._coroutineChange(_scheduler, to);
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
      next = Coroutine._coroutineChange(next._coroutine, null);
    }
  }
}
