// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// This file contains options to the dartino_entry file when building it
// using gyp. When building with the `dartino` tool a corresponding file is
// created from the embedder_options in the .dartino-settings file.
// TODO(sigurdm): Use the same pipeline to link and flash the disco_dartino app
// as the user will do when deploying an app. Thus getting rid of this file.

const char *dartino_embedder_options[] = {
  "uart_print_interceptor",
//  "enable_debugger",
  0
};
