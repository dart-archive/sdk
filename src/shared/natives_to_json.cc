// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <sys/errno.h>

#include "src/shared/assert.h"

#include "src/shared/names.h"
#include "src/shared/natives.h"

namespace fletch {

static int Main(int argc, char** argv) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s <output_file>", argv[0]);
    return 1;
  }
  FILE* output = fopen(argv[1], "w");
  if (output == NULL) {
    fprintf(stderr, "%s: Unable to write \"%s\": %s\n", argv[0], argv[1],
            strerror(errno));
    return 1;
  }

  const char* prefix = "";
  fprintf(output, "{\"natives\": [\n");
#define N(e, c, n)                                \
  fprintf(output, "%s  {\n", prefix);             \
  fprintf(output, "    \"enum\": \"%s\",\n", #e); \
  fprintf(output, "    \"class\": \"%s\",\n", c); \
  fprintf(output, "    \"name\": \"%s\"\n", n);   \
  fprintf(output, "  }");                         \
  prefix = ",\n";
  NATIVES_DO(N)
#undef N
  fprintf(output, "\n], \"names\": [\n");
  prefix = "";
#define N(n, v)                                   \
  fprintf(output, "%s  {\n", prefix);             \
  fprintf(output, "    \"name\": \"%s\",\n", #n); \
  fprintf(output, "    \"value\": \"%s\"\n", v);  \
  fprintf(output, "  }");                         \
  prefix = ",\n";
  NAMES_LIST(N)
#undef N
  fprintf(output, "\n]\n");
  fprintf(output, "}\n");

  if (fclose(output) != 0) {
    fprintf(stderr, "%s: Unable to close \"%s\": %s\n", argv[0], argv[1],
            strerror(errno));
    return 1;
  }
  return 0;
}

}  // namespace fletch

// Forward main calls to fletch::Main.
int main(int argc, char** argv) { return fletch::Main(argc, argv); }
