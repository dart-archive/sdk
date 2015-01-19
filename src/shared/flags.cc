// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/flags.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

namespace fletch {

char* Flags::executable_ = NULL;

// Tells whether the given string is a valid flag argument.
static bool IsValidFlag(const char* argument) {
  return (strncmp(argument, "-X", 2) == 0) && (strlen(argument) > 2);
}

#ifdef DEBUG

class Flag {
 public:
  // Initialize the flag by parsing argument.
  void Parse(char* argument);

  // Print the flag with its value.
  void Print() const;

  bool IsOn() {
    if (kind_ == kNoValueKind) return true;
    if (kind_ == kBoolKind) return value_.b;
    return false;
  }

  bool IsBool(bool* value) {
    if (kind_ != kBoolKind) return false;
    *value = value_.b;
    return true;
  }

  bool IsInt(int* value) {
    if (kind_ != kIntValue) return false;
    *value = value_.i;
    return true;
  }

  bool IsAddress(uword* value) {
    if (kind_ != kAddressKind) return false;
    *value = value_.a;
    return true;
  }

  bool IsString(char** value) {
    if (kind_ != kStringKind) return false;
    *value = value_.s;
    return true;
  }

  const char* name() const { return name_; }

 private:
  enum Kind {
    kNoValueKind,
    kBoolKind,
    kIntValue,
    kAddressKind,
    kStringKind
  };

  // Data fields.
  char* name_;
  Kind kind_;
  union {
    int i;
    char* s;
    bool b;
    uword a;
  } value_;
};

void Flag::Print() const {
  printf(" - %s", name());
  switch (kind_) {
    case kIntValue:
      printf("=%d (int)\n", value_.i);
      break;
    case kBoolKind:
      printf("=%s (bool)\n", value_.b ? "true" : "false");
      break;
    case kStringKind:
      printf("=%s (string)\n", value_.s);
      break;
    case kAddressKind:
      printf("=0x%lx (address)\n", value_.a);
      break;
    case kNoValueKind:
      printf(" (no value)\n");
      break;
  }
}

void Flag::Parse(char* argument) {
  static const int kPrefixLength = strlen("-X");

  ASSERT(IsValidFlag(argument));
  argument = argument + kPrefixLength;

  // Parse the name of the flag.
  const char* p = argument;
  while (*argument != '\0' && *argument != '=') argument++;
  name_ = static_cast<char*>(malloc(1+ argument - p));
  strncpy(name_, p, argument - p);
  name_[argument - p] = '\0';

  // Check for flags without a value.
  if (*argument++ != '=' || *argument == '\0') {
    kind_ = kNoValueKind;
    return;
  }

  // Check for int value.
  char* end;
  int i_value = strtol(argument, &end, 10);  // NOLINT
  if (*end == '\0') {
    kind_ = kIntValue;
    value_.i = i_value;
    return;
  }

  // Check for address value.
  uword a_value = strtoll(argument, &end, 16);  // NOLINT
  if (*end == '\0') {
    kind_ = kAddressKind;
    value_.a = a_value;
    return;
  }

  // Check for bool values.
  if (strcmp(argument, "false") == 0) {
    kind_ = kBoolKind;
    value_.b = false;
    return;
  }

  if (strcmp(argument, "true") == 0) {
    kind_ = kBoolKind;
    value_.b = true;
    return;
  }

  // Default to string value.
  kind_ = kStringKind;
  value_.s = argument;
}

// Maintain a list of parsed flags in debug mode.
static Flag* flags_ = NULL;
static int number_of_flags_ = 0;

static Flag* LookupFlag(const char* name) {
  for (int i = 0; i < number_of_flags_; i++) {
    if (strcmp(flags_[i].name(), name) == 0) return &flags_[i];
  }
  return NULL;
}

bool Flags::SlowIsOn(const char* name) {
  Flag* flag = LookupFlag(name);
  if (flag != NULL) return flag->IsOn();
  return false;
}

bool Flags::SlowIsBool(const char* name, bool* value) {
  Flag* flag = LookupFlag(name);
  if (flag != NULL) return flag->IsBool(value);
  return false;
}

bool Flags::SlowIsInt(const char* name, int* value) {
  Flag* flag = LookupFlag(name);
  if (flag != NULL) return flag->IsInt(value);
  return false;
}

bool Flags::SlowIsAddress(const char* name, uword* value) {
  Flag* flag = LookupFlag(name);
  if (flag != NULL) return flag->IsAddress(value);
  return false;
}

bool Flags::SlowIsString(const char* name, char** value) {
  Flag* flag = LookupFlag(name);
  if (flag != NULL) return flag->IsString(value);
  return false;
}

#endif

static void ShrinkArguments(int* argc, char** argv) {
  int eliminated = 0;
  int j = 1;
  for (int i = 1; i < *argc; i++) {
    if (argv[i] != NULL) {
      argv[j++] = argv[i];
    } else {
      eliminated++;
    }
  }
  *argc = *argc - eliminated;
}

void Flags::ExtractFromCommandLine(int* argc, char** argv) {
  // Set the executable name.
  executable_ = argv[0];
  // Compute number of provided flag arguments.
  int number_of_flags = 0;
  for (int i = 1; i < *argc; i++) {
    if (IsValidFlag(argv[i])) number_of_flags++;
  }
#ifdef DEBUG
  number_of_flags_ = number_of_flags;
#endif
  if (number_of_flags == 0) return;

#ifdef DEBUG
  // Allocate the flag structure.
  flags_ = static_cast<Flag*>(calloc(number_of_flags_, sizeof(Flag)));
  int number = 0;
#endif

  // Fill in the individual flags.
  for (int i = 1; i < *argc; i++) {
    if (IsValidFlag(argv[i])) {
#ifdef DEBUG
      flags_[number++].Parse(argv[i]);
#endif
      argv[i] = NULL;
    }
  }

  // Get rid of all the NULL'ed out arguments.
  ShrinkArguments(argc, argv);

#ifdef DEBUG
  // Print list of flags if requested.
  if (IsOn("print-flags")) {
    printf("Command line flags:\n");
    for (int i = 0; i < number_of_flags_; i++) {
      flags_[i].Print();
    }
  }
#endif
}

}  // namespace fletch
