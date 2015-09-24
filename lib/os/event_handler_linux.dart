// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.fletch.os;

const int EPOLLIN       = 0x1;
const int EPOLLOUT      = 0x4;
const int EPOLLERR      = 0x8;
const int EPOLLHUP      = 0x10;
const int EPOLLRDHUP    = 0x2000;
const int EPOLLONESHOT  = 0x40000000;

const int EPOLL_CTL_ADD = 1;
const int EPOLL_CTL_DEL = 2;
const int EPOLL_CTL_MOD = 3;

class _EpollEvent extends ForeignMemory {
  // epoll_event is packed on ia32/x64, but not on arm.
  static int eventSize = Foreign.architecture == Foreign.ARM ? 8 : 4;

  _EpollEvent() : super.allocatedFinalized(eventSize + 8);

  int get events => getInt32(0);
  void set events(int value) {
    setInt32(0, value);
  }

  int get data => getInt64(eventSize);
  void set data(int value) {
    setInt64(eventSize, value);
  }
}

class LinuxEventHandler extends EventHandler {
  static final ForeignFunction _epollCtl =
      ForeignLibrary.main.lookup("epoll_ctl");
  static final ForeignFunction _lseekLinux =
      ForeignLibrary.main.lookup("lseek64");
  static final ForeignFunction _openLinux =
      ForeignLibrary.main.lookup("open64");

  final _EpollEvent _epollEvent = new _EpollEvent();

  int get FIONREAD => 0x541B;

  int get SOL_SOCKET => 1;

  int get SO_REUSEADDR => 2;

  ForeignFunction get _lseek => _lseekLinux;
  ForeignFunction get _open => _openLinux;

  int addToEventHandler(int fd) {
    _epollEvent.events = 0;
    _epollEvent.data = 0;
    int eh = EventHandler.eventHandler;
    return  _epollCtl.icall$4Retry(eh, EPOLL_CTL_ADD, fd, _epollEvent);
  }

  int removeFromEventHandler(int fd) {
    // TODO(ajohnsen): If we increased the refcount of the port before adding it
    // to the epoll set and we remove it now, we can leak memory.
    int eh = EventHandler.eventHandler;
    return _epollCtl.icall$4Retry(eh, EPOLL_CTL_DEL, fd, ForeignPointer.NULL);
  }

  int setPortForNextEvent(int fd, Port port, int mask) {
    int events = EPOLLRDHUP | EPOLLHUP | EPOLLONESHOT;
    if ((mask & READ_EVENT) != 0) events |= EPOLLIN;
    if ((mask & WRITE_EVENT) != 0) events |= EPOLLOUT;
    _epollEvent.events = events;
    _epollEvent.data = EventHandler._incrementPortRef(port);
    int eh = EventHandler.eventHandler;
    return _epollCtl.icall$4Retry(eh, EPOLL_CTL_MOD, fd, _epollEvent);
  }
}
