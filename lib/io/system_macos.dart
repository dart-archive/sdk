// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of system;

const int EVFILT_READ   = -1;
const int EVFILT_WRITE  = -2;

const int EV_ADD      = 0x1;
const int EV_DELETE   = 0x2;
const int EV_ENABLE   = 0x4;
const int EV_DISABLE  = 0x8;
const int EV_ONESHOT  = 0x10;
const int EV_CLEAR    = 0x20;
const int EV_EOF      = 0x8000;

class MacOSAddrInfo extends AddrInfo {
  MacOSAddrInfo() : super._();
  MacOSAddrInfo.fromAddress(int address) : super._fromAddress(address);

  get ai_canonname {
    int offset = _addrlenOffset + wordSize;
    return getWord(offset);
  }

  ForeignMemory get ai_addr {
    int offset = _addrlenOffset + wordSize * 2;
    return new ForeignMemory.fromAddress(getWord(offset), ai_addrlen);
  }

  AddrInfo get ai_next {
    int offset = _addrlenOffset + wordSize * 3;
    return new MacOSAddrInfo.fromAddress(getWord(offset));
  }
}

class KEvent extends Struct {
  KEvent() : super.finalize(6);

  void clear() {
    for (int i = 0; i < length; i += wordSize) setWord(i, 0);
  }

  get ident => getWord(0);
  void set ident(int value) {
    setWord(0, value);
  }

  get filter => getInt16(wordSize);
  void set filter(int value) {
    setInt16(wordSize, value);
  }

  get flags => getUint16(wordSize + 2);
  void set flags(int value) {
    setUint16(wordSize + 2, value);
  }

  get fflags => getInt32(wordSize + 4);
  get data => getWord(wordSize + 8);
  get udata => getWord(wordSize + 8 + wordSize);
  void set udata(int value) {
    setWord(wordSize + 8 + wordSize, value);
  }
}

class MacOSSystem extends PosixSystem {
  static final ForeignFunction _kevent = ForeignLibrary.main.lookup("kevent");
  static final ForeignFunction _lseekMac = ForeignLibrary.main.lookup("lseek");
  static final ForeignFunction _openMac = ForeignLibrary.main.lookup("open");

  final KEvent _kEvent = new KEvent();

  int get FIONREAD => 0x4004667f;

  int get SOL_SOCKET => 0xffff;

  int get SO_REUSEADDR => 0x4;

  ForeignFunction get _lseek => _lseekMac;
  ForeignFunction get _open => _openMac;

  int _setEvents(bool read, bool write) {
    int eh = System.eventHandler;
    int status = 0;
    if (read) {
      _kEvent.filter = EVFILT_READ;
      status = _kevent.icall$6Retry(
          eh, _kEvent, 1, ForeignPointer.NULL, 0, ForeignPointer.NULL);
    }
    if (status != -1 && write) {
      _kEvent.filter = EVFILT_WRITE;
      status = _kevent.icall$6Retry(
          eh, _kEvent, 1, ForeignPointer.NULL, 0, ForeignPointer.NULL);
    }
    return status;
  }

  int addToEventHandler(int fd) { }

  int removeFromEventHandler(int fd) { }

  int setPortForNextEvent(int fd, Port port, int mask) {
    if (mask != READ_EVENT && mask != WRITE_EVENT) {
      throw "Listening for both READ_EVENT and WRITE_EVENT is currently"
            " unsupported on mac os.";
    }
    _kEvent.clear();
    _kEvent.ident = fd;
    _kEvent.flags = EV_ADD | EV_ONESHOT;
    _kEvent.udata = System._incrementPortRef(port);
    return _setEvents((mask & READ_EVENT) != 0, (mask & WRITE_EVENT) != 0);
  }
}
