// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;
import 'dart:fletch';
import 'dart:fletch.io';
import 'dart:math';

const patch = "patch";

Channel _eventQueue;
_FletchTimer _timers;
int _numberOfEvents = 0;

void _handleEvents() {
  while (_numberOfEvents > 0) {
    var event = _eventQueue.receive();
    _numberOfEvents--;
    event();
  }
  _eventQueue = null;
}

Channel _ensureEventQueue() {
  if (_eventQueue == null) {
    _eventQueue = new Channel();
    Fiber.fork(_handleEvents);
  }
  return _eventQueue;
}

@patch class _AsyncRun {
  @patch static void _scheduleImmediate(void callback()) {
    _numberOfEvents++;
    _ensureEventQueue().send(callback);
  }
}

final int _maxWaitTimeInMilliseconds = 1000;

final int _baseTime = new DateTime.now().millisecondsSinceEpoch;

int get _currentTimestamp {
  return new DateTime.now().millisecondsSinceEpoch - _baseTime;
}

// TODO(ager): This is a pretty horrible implementation. We should get
// this integrated with the event loop. For now this is enough to show
// that we can implement async on top of our current primitives.
class _FletchTimer implements Timer {
  final int _milliseconds;
  var _callback;
  int _timestamp = 0;
  _FletchTimer _next;
  bool _isActive = true;
  bool _hasActiveWaitFiber = false;

  bool get _isPeriodic => _milliseconds >= 0;

  _FletchTimer(this._timestamp, this._callback)
      : _milliseconds = -1 {
    _schedule();
    _forkWaitFiber();
  }

  _FletchTimer.periodic(this._timestamp,
                        void callback(Timer timer),
                        this._milliseconds) {
    _callback = () { callback(this); };
    _schedule();
    _forkWaitFiber();
  }

  void _forkWaitFiber() {
    if (_timers != this) return;
    assert(!_hasActiveWaitFiber);
    _hasActiveWaitFiber = true;
    Fiber.fork(() {
      var milliseconds = _timestamp - _currentTimestamp;
      if (milliseconds < 0) milliseconds = 0;
      // Cap the sleep time so that a timer that is set way in the
      // future will not cause the system to keep running if it is
      // cancelled.
      if (milliseconds > _maxWaitTimeInMilliseconds) {
        milliseconds = _maxWaitTimeInMilliseconds;
      }

      Channel channel = new Channel();
      Port port = new Port(channel);
      Process.spawn((int milliseconds) {
        sleep(milliseconds);
        port.send(null);
      }, milliseconds);
      channel.receive();

      _hasActiveWaitFiber = false;
      _fireExpiredTimers();
    });
  }

  void _fireExpiredTimers() {
    // Skip cancelled timers.
    while (_timers != null && !_timers._isActive) _timers = _timers._next;
    if (_timers != null) {
      // If first timer is expired, fire it and reschedule if it is
      // periodic.
      if (_currentTimestamp >= _timers._timestamp) {
        _AsyncRun._scheduleImmediate(_timers._callback);
        var current = _timers;
        _timers = _timers._next;
        if (current._isPeriodic) current._reschedule();
      }
      // Spin up a timer fiber if there isn't already one for
      // the next timer to fire.
      if (_timers != null && !_timers._hasActiveWaitFiber) {
        _timers._forkWaitFiber();
      }
    }
  }

  void _schedule() {
    var lastWithSmallerTimestamp = null;
    for (_FletchTimer current = _timers;
         current != null;
         current = current._next) {
      if (current._timestamp > _timestamp) break;
      lastWithSmallerTimestamp = current;
    }
    if (lastWithSmallerTimestamp == null) {
      _next = _timers;
      _timers = this;
    } else {
      _next = lastWithSmallerTimestamp._next;
      lastWithSmallerTimestamp._next = this;
    }
  }

  void _reschedule() {
    assert(_isPeriodic);
    _timestamp = _currentTimestamp + _milliseconds;
    _schedule();
  }

  void cancel() {
    _isActive = false;
  }

  bool get isActive => _isActive;
}

@patch class Timer {
  @patch static Timer _createTimer(Duration duration, void callback()) {
    int milliseconds = max(0, duration.inMilliseconds);
    return new _FletchTimer(_currentTimestamp + milliseconds, callback);
  }

  @patch static Timer _createPeriodicTimer(Duration duration,
                                           void callback(Timer timer)) {
    int milliseconds = max(0, duration.inMilliseconds);
    return new _FletchTimer.periodic(_currentTimestamp + milliseconds,
                                     callback,
                                     milliseconds);
  }
}
