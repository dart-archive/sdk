// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'json.dart';

class Server {
  static const githubApiUrl = 'https://api.github.com';
  final String host;
  final int port;

  List<Channel> outstanding = [];

  Server(this.host, this.port);

  void close() {
    var local = outstanding;
    outstanding = [];
    for (Channel channel in local) channel.receive();
  }

  dynamic get(String resource) => getJson(host, port, resource);

  User getUser(String name) => new User(name, this);
}

abstract class Service {
  final String api;
  final Server server;

  var _data = null;

  Service(this.api, this.server);

  dynamic operator[](String key) {
    _ensureData();
    return _data[key];
  }

  void _ensureData() {
    if (_data != null) return;
    _data = server.get(api);
  }
}

class User extends Service {
  final String name;

  User(String name, Server parent)
      : super('users/$name', parent),
        this.name = name;

  Repository getRepository(String repo) => new Repository(repo, this);
}

class Repository extends Service {
  final String name;
  final Pagination _commitPages;

  Repository(String name, User parent)
      : super('repos/${parent.name}/$name', parent.server),
        this.name = name,
        _commitPages = new Pagination(
            'repos/${parent.name}/$name/commits', parent.server);

  dynamic getCommitAt(int index) => _commitPages.itemAt(index);

  void prefetchCommitsInRange(int start, int end) =>
      _commitPages.prefetchItemsInRange(start, end);
}

class Pagination {
  static const count = 30;

  final Server server;
  final String api;
  List _pages = [];

  Pagination(this.api, this.server);

  void prefetch(int page) {
    _fetch(page, true);
  }

  List fetch(int page) {
    return _fetch(page, false);
  }

  void prefetchItemsInRange(int start, int end) {
    int firstPage = start ~/ count;
    int lastPage = (end ~/ count) + 1;
    // Scheduling prefetching of surrounding pages in descending order.
    // (Currently the fletch scheduler will process these in reverse order).
    if (firstPage > 0) prefetch(firstPage - 1);
    prefetch(lastPage + 1);
    for (int i = lastPage; i >= firstPage; --i) {
      prefetch(i);
    }
  }

  dynamic itemAt(int index) {
    int page = index ~/ count;
    int entry = index % count;
    List entries = fetch(page);
    return (entries != null && entry < entries.length) ? entries[entry] : null;
  }

  _fetch(int page, bool prefetch) {
    var entries = null;
    if (_pages.length <= page) {
      _pages.length = page + 1;
    } else {
      entries = _pages[page];
    }
    if (entries is Channel) {
      if (prefetch) return;
      return entries.receive();
    }
    if (entries == null) {
      Channel channel = new Channel();
      _pages[page] = channel;
      if (prefetch) {
        server.outstanding.add(channel);
        Thread.fork(() {
          _doFetch(channel, page);
          server.outstanding.remove(channel);
        });
      } else {
        return _doFetch(channel, page);
      }
    }
    return entries;
  }

  List _doFetch(Channel channel, int page) {
    List entries = null;
    try {
      entries = server.get('$api?page=${page + 1}');
    } catch (_) {
      // Throws once when we hit past the last page.
    }
    _pages[page] = entries;
    channel.send(entries);
    return entries;
  }
}
