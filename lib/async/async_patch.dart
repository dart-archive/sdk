// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch._system' as fletch;
import 'dart:fletch';
import 'dart:fletch.os' as os;
import 'dart:math';

const patch = "patch";

Channel _eventQueue;
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

int get _currentTimestamp {
  return new DateTime.now().millisecondsSinceEpoch;
}

// TODO(ajohnsen): We should create a heap-like structure in Dart, so we only
// have one active port/channel per process.
class _FletchTimer implements Timer {
  final int _milliseconds;
  var _callback;
  int _timestamp = 0;
  _FletchTimer _next;
  bool _isActive = true;
  Channel _channel;
  Port _port;

  bool get _isPeriodic => _milliseconds >= 0;

  _FletchTimer(this._timestamp, this._callback)
      : _milliseconds = -1 {
    _channel = new Channel();
    _port = new Port(_channel);
    _schedule();
  }

  _FletchTimer.periodic(this._timestamp,
                        void callback(Timer timer),
                        this._milliseconds) {
    _callback = () { callback(this); };
    _channel = new Channel();
    _port = new Port(_channel);
    _schedule();
  }

  void _schedule() {
    Fiber.fork(() {
      int value = _channel.receive();
      if (value == 0 && _isActive) {
        _callback();
        if (_isPeriodic && _isActive) {
          _reschedule();
        } else {
          _isActive = false;
        }
      }
    });
    _scheduleTimeout(_timestamp, _port);
  }

  void _reschedule() {
    assert(_isPeriodic);
    _timestamp += _milliseconds;
    _schedule();
  }

  void cancel() {
    _scheduleTimeout(-1, _port);
    _port.send(-1);
    _isActive = false;
  }

  bool get isActive => _isActive;

  @fletch.native external static void _scheduleTimeout(int timeout, Port port);
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
