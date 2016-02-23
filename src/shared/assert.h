// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_ASSERT_H_
#define SRC_SHARED_ASSERT_H_

#ifdef TESTING
#include <sstream>
#include <string>
#endif

#include <assert.h>
#ifdef static_assert
#undef static_assert
#endif

#include "src/shared/globals.h"

namespace dartino {
namespace DynamicAssertionHelper {

template <typename K>
void Fail(const char* file, int line, const char* format, ...);

// two specializations of the above helper routine
class ASSERT;
class EXPECT;

template <>
void Fail<ASSERT>(const char* file, int line, const char* format, ...);
template <>
void Fail<EXPECT>(const char* file, int line, const char* format, ...);

// Only allow the expensive (with respect to code size) assertions
// in testing code.
#ifdef TESTING
template <typename K, typename E, typename A>
void Equals(const char* file, int line, const E& expected, const A& actual) {
  if (actual == expected) return;
  std::stringstream ess, ass;
  ess << expected;
  ass << actual;
  std::string es = ess.str(), as = ass.str();
  Fail<K>(file, line, "expected: <%s> but was: <%s>", es.c_str(), as.c_str());
}

template <typename K, typename E, typename A>
void StringEquals(const char* file, int line, const E& expected,
                  const A& actual) {
  std::stringstream ess, ass;
  ess << expected;
  ass << actual;
  std::string es = ess.str(), as = ass.str();
  if (as == es) return;
  Fail<K>(file, line, "expected: <\"%s\"> but was: <\"%s\">", es.c_str(),
          as.c_str());
}

template <typename K, typename E, typename A>
void LessThan(const char* file, int line, const E& left, const A& right) {
  if (left < right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail<K>(file, line, "expected: %s < %s", es.c_str(), as.c_str());
}

template <typename K, typename E, typename A>
void LessEqual(const char* file, int line, const E& left, const A& right) {
  if (left <= right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail<K>(file, line, "expected: %s <= %s", es.c_str(), as.c_str());
}

template <typename K, typename E, typename A>
void GreaterThan(const char* file, int line, const E& left, const A& right) {
  if (left > right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail<K>(file, line, "expected: %s > %s", es.c_str(), as.c_str());
}

template <typename K, typename E, typename A>
void GreaterEqual(const char* file, int line, const E& left, const A& right) {
  if (left >= right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail<K>(file, line, "expected: %s >= %s", es.c_str(), as.c_str());
}
#endif  // ifdef TESTING

}  // namespace DynamicAssertionHelper
}  // namespace dartino

#define FATAL(error)                    \
  dartino::DynamicAssertionHelper::Fail< \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, "%s", error)

#define FATAL1(format, p1)                                                \
  dartino::DynamicAssertionHelper::Fail<                                   \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, format, \
                                              (p1))

#define FATALV(format, ...) \
  dartino::DynamicAssertionHelper::Fail<                           \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, \
                                               format, __VA_ARGS__)

#define UNIMPLEMENTED() FATAL("unimplemented code")

#define UNREACHABLE() FATAL("unreachable code")

#if !defined(TESTING)
// Only define the minimal set of assertions when not building the test
// binaries.

// If the system already has an assert of its own, undefine it here so that
// ours gets used.
#ifdef ASSERT
#undef ASSERT
#endif

#if defined(DEBUG)
// DEBUG binaries use assertions in the code. Due to concerns about the code
// size we do not use the Equals templates for the ASSERT_EQ at the moment.

#define ASSERT(condition)                                                    \
  if (!(condition)) {                                                        \
    dartino::DynamicAssertionHelper::Fail<                                    \
        dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__,          \
                                                "expected: %s", #condition); \
  }

#else  // if defined(DEBUG)

// In order to avoid variable unused warnings for code that only uses
// a variable in an ASSERT or EXPECT, we make sure to use the macro
// argument.
#define ASSERT(condition)        \
  while (false && (condition)) { \
  }

#endif  // if defined(DEBUG)

#else  // if !defined(TESTING)
// TESTING is defined when building the test files. They do have a much wider
// variety of checks and error reporting available when compared to the normal
// runtime code. Also all of the checks are enabled for the tests themselves.
// The runtime code only has assertions enabled when running the debug test
// binaries.

#define ASSERT(condition)                                                    \
  if (!(condition)) {                                                        \
    dartino::DynamicAssertionHelper::Fail<                                    \
        dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__,          \
                                                "expected: %s", #condition); \
  }

#define ASSERT_EQ(expected, actual)                                           \
  dartino::DynamicAssertionHelper::Equals<                                     \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, (expected), \
                                              (actual))

#define ASSERT_STREQ(expected, actual)                                        \
  dartino::DynamicAssertionHelper::StringEquals<                               \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, (expected), \
                                              (actual))

#define ASSERT_LT(left, right)                                            \
  dartino::DynamicAssertionHelper::LessThan<                               \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, (left), \
                                              (right))

#define ASSERT_LE(left, right)                                            \
  dartino::DynamicAssertionHelper::LessEqual<                              \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, (left), \
                                              (right))

#define ASSERT_GT(left, right)                                            \
  dartino::DynamicAssertionHelper::GreaterThan<                            \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, (left), \
                                              (right))

#define ASSERT_GE(left, right)                                            \
  dartino::DynamicAssertionHelper::GreaterEqual<                           \
      dartino::DynamicAssertionHelper::ASSERT>(__FILE__, __LINE__, (left), \
                                              (right))

#define EXPECT(condition)                                                    \
  if (!(condition)) {                                                        \
    dartino::DynamicAssertionHelper::Fail<                                    \
        dartino::DynamicAssertionHelper::EXPECT>(__FILE__, __LINE__,          \
                                                "expected: %s", #condition); \
  }

#define EXPECT_EQ(expected, actual)                                           \
  dartino::DynamicAssertionHelper::Equals<                                     \
      dartino::DynamicAssertionHelper::EXPECT>(__FILE__, __LINE__, (expected), \
                                              (actual))

#define EXPECT_STREQ(expected, actual)                                        \
  dartino::DynamicAssertionHelper::StringEquals<                               \
      dartino::DynamicAssertionHelper::EXPECT>(__FILE__, __LINE__, (expected), \
                                              (actual))

#define EXPECT_LT(left, right)                                            \
  dartino::DynamicAssertionHelper::LessThan<                               \
      dartino::DynamicAssertionHelper::EXPECT>(__FILE__, __LINE__, (left), \
                                              (right))

#define EXPECT_LE(left, right)                                            \
  dartino::DynamicAssertionHelper::LessEqual<                              \
      dartino::DynamicAssertionHelper::EXPECT>(__FILE__, __LINE__, (left), \
                                              (right))

#define EXPECT_GT(left, right)                                            \
  dartino::DynamicAssertionHelper::GreaterThan<                            \
      dartino::DynamicAssertionHelper::EXPECT>(__FILE__, __LINE__, (left), \
                                              (right))

#define EXPECT_GE(left, right)                                            \
  dartino::DynamicAssertionHelper::GreaterEqual<                           \
      dartino::DynamicAssertionHelper::EXPECT>(__FILE__, __LINE__, (left), \
                                              (right))

#endif  // if !defined(TESTING)

#endif  // SRC_SHARED_ASSERT_H_
