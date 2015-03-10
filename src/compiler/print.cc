// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/builder.h"
#include "src/shared/flags.h"
#include "src/shared/fletch.h"
#include "src/compiler/library_loader.h"
#include "src/compiler/os.h"
#include "src/compiler/pretty_printer.h"

namespace fletch {

LibraryElement* Load(LibraryLoader* loader,
                     const char* library_root,
                     const char* uri) {
  Zone zone;
  return loader->LoadLibrary(uri, uri);
}

int Print(const char* library_root, const char* uri) {
  Zone zone;
  Builder builder(&zone);
  LibraryLoader loader(&builder, library_root, "package/");

  LibraryElement* root = Load(&loader, library_root, uri);
  if (root == NULL) return 1;

  PrettyPrinter printer(&zone, true);
  printer.DoLibrary(root->library());

  printf("%s\n", printer.Output());

  return 0;
}

}  // namespace fletch

int main(int argc, char** argv) {
  fletch::Flags::ExtractFromCommandLine(&argc, argv);
  fletch::Fletch::Setup();
  if (argc != 2) {
    fprintf(stderr, "Usage: %s <entry>\n", argv[0]);
    return 1;
  }
  const char* library_root =
      fletch::OS::UriResolve(argv[0], "../../lib/", NULL);
  int result = fletch::Print(library_root, argv[1]);
  fletch::Fletch::TearDown();
  return result;
}
