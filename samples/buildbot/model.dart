// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class Project {
  String name;
  Console console;
  Project(this.name);
}

class Console {
  String title;
  String apiUrl;
  String statusUrl;
  Console(this.title, this.apiUrl, this.statusUrl);

  // TODO(zerny): compute from ${statusUrl}/current?format=json
  String get status => "status unknown";
}
