// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/compiler/builder.h"
#include "src/shared/flags.h"
#include "src/shared/fletch.h"
#include "src/shared/globals.h"
#include "src/compiler/os.h"
#include "src/compiler/parser.h"
#include "src/compiler/scanner.h"

namespace fletch {

int64 scan_time = 0;
int64 parse_time = 0;
int64 io_time = 0;

int Scan(const char* filename, Builder* builder) {
  Zone zone;

  int64 start = OS::CurrentTime();
  // Open the file.
  FILE* file = fopen(filename, "rb");
  if (file == NULL) {
    printf("ERROR: Cannot open %s\n", filename);
    return 0;
  }

  // Determine the size of the file.
  if (fseek(file, 0, SEEK_END) != 0) {
    printf("ERROR: Cannot seek in file %s\n", filename);
    fclose(file);
    return 0;
  }
  int size = ftell(file);
  rewind(file);

  // Read in the entire file.
  char* buffer = static_cast<char*>(zone.Allocate(size + 1));
  int result = fread(buffer, 1, size, file);
  fclose(file);
  if (result != size) {
    printf("ERROR: Unable to read entire file %s\n", filename);
    return 0;
  }
  buffer[size] = '\0';
  int64 end = OS::CurrentTime();
  io_time += end - start;

  if (Flags::verbose) {
    printf("Scanning %s (%d bytes)\n", filename, size);
  }
  start = OS::CurrentTime();

  // Scan the file.
  Scanner scanner(builder, &zone);
  scanner.Scan(buffer, Location());
  List<TokenInfo> tokens = scanner.EncodedTokens();

  end = OS::CurrentTime();
  scan_time += end - start;
  if (Flags::verbose) {
    printf("  - scanned in %" PRId64 " us.\n", end - start);
    printf("  - generated %d tokens (%zd bytes).\n",
        tokens.length(), tokens.length() * sizeof(TokenInfo));
  }

  start = OS::CurrentTime();
  // Parse the file.
  Parser parser(builder, tokens);
  parser.ParseCompilationUnit();

  end = OS::CurrentTime();
  parse_time += end - start;
  if (Flags::verbose) {
    printf("  - parsed in %" PRId64 " us.\n", end - start);
  }

  return tokens.length() * sizeof(TokenInfo);
}

}  // namespace fletch


int main(int argc, char** argv) {
  int64 start = fletch::OS::CurrentTime();
  fletch::Flags::ExtractFromCommandLine(&argc, argv);
  fletch::Fletch::Setup();

  fletch::Zone zone;
  fletch::Builder builder(&zone);

  int total = 0;
  for (int i = 1; i < argc; i++) {
    total += fletch::Scan(argv[i], &builder);
  }

  printf("\nDone scanning\n");
  printf("  - token-stream size: %d bytes.\n", total);

  fletch::List<fletch::TreeNode*> registry = builder.Registry();

  int64 end = fletch::OS::CurrentTime();
  int64 total_time = end - start;

  printf("  - generated %d terminals.\n", registry.length());
  for (int i = 0; i < registry.length(); i++) {
    fletch::IdentifierNode* in = registry[i]->AsIdentifier();
    fletch::LiteralIntegerNode* nn = registry[i]->AsLiteralInteger();
    fletch::LiteralStringNode* sn = registry[i]->AsLiteralString();
    if (in != NULL) {
      total += sizeof(fletch::IdentifierNode) + strlen(in->value()) + 1;
    } else if (nn != NULL) {
      total += sizeof(fletch::LiteralIntegerNode);
    } else if (sn != NULL) {
      total += sizeof(fletch::LiteralStringNode) + strlen(sn->value()) + 1;
    }
  }
  printf("  - total token-stream size: %d bytes.\n", total);
#ifdef DEBUG
  printf("  - total zone allocated: %ld bytes.\n", fletch::Zone::allocated());
#endif

  printf("\nTotal time used: %" PRId64 " us.\n", total_time);
  printf("  - io time: %" PRId64 " us.\n", fletch::io_time);
  printf("  - total scan time: %" PRId64 " us.\n", fletch::scan_time);
  printf("  - total parse time: %" PRId64 " us.\n", fletch::parse_time);

  fletch::Fletch::TearDown();

  return 0;
}
