// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

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
  void send(message) native catch (error) {
    if (error == _wrongArgumentType) {
      throw new ArgumentError();
    } else if (error == _illegalState) {
      throw new StateError("Port is closed.");
    } else {
      throw error;
    }
  }

  // Send multiple messages to the channel. Not blocking.
  void sendMultiple(Iterable iterable) {
    _sendList(iterable.toList(growable: true), _portListSentinel);
  }

  void _sendList(List list, sentinel) native catch (error) {
    if (error == _wrongArgumentType) {
      throw new ArgumentError();
    } else if (error == _illegalState) {
      throw new StateError("Port is closed.");
    } else {
      throw error;
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

  static int _create(Channel channel, Port port) native;
  static void _close(int port, Port port) native;
  static void _incrementRef(int port) native;
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
