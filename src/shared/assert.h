// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_ASSERT_H_
#define SRC_SHARED_ASSERT_H_

#ifdef TESTING
#include <sstream>
#include <string>
#endif

#include <assert.h>

#include "src/shared/globals.h"

namespace fletch {

class DynamicAssertionHelper {
 public:
  enum Kind {
    ASSERT,
    EXPECT
  };

  DynamicAssertionHelper(const char* file, int line, Kind kind)
      : file_(file), line_(line), kind_(kind) { }

  void Fail(const char* format, ...);

#ifdef TESTING
  template<typename E, typename A>
  void Equals(const E& expected, const A& actual);

  template<typename E, typename A>
  void StringEquals(const E& expected, const A& actual);

  template<typename E, typename A>
  void LessThan(const E& left, const A& right);

  template<typename E, typename A>
  void LessEqual(const E& left, const A& right);

  template<typename E, typename A>
  void GreaterThan(const E& left, const A& right);

  template<typename E, typename A>
  void GreaterEqual(const E& left, const A& right);
#endif

 private:
  const char* const file_;
  const int line_;
  const Kind kind_;

  DISALLOW_IMPLICIT_CONSTRUCTORS(DynamicAssertionHelper);
};

class Assert: public DynamicAssertionHelper {
 public:
  Assert(const char* file, int line)
      : DynamicAssertionHelper(file, line, ASSERT) { }
};

class Expect: public DynamicAssertionHelper {
 public:
  Expect(const char* file, int line)
      : DynamicAssertionHelper(file, line, EXPECT) { }
};

// Only allow the expensive (with respect to code size) assertions
// in testing code.
#ifdef TESTING
template<typename E, typename A>
void DynamicAssertionHelper::Equals(const E& expected, const A& actual) {
  if (actual == expected) return;
  std::stringstream ess, ass;
  ess << expected;
  ass << actual;
  std::string es = ess.str(), as = ass.str();
  Fail("expected: <%s> but was: <%s>", es.c_str(), as.c_str());
}

template<typename E, typename A>
void DynamicAssertionHelper::StringEquals(const E& expected, const A& actual) {
  std::stringstream ess, ass;
  ess << expected;
  ass << actual;
  std::string es = ess.str(), as = ass.str();
  if (as == es) return;
  Fail("expected: <\"%s\"> but was: <\"%s\">", es.c_str(), as.c_str());
}

template<typename E, typename A>
void DynamicAssertionHelper::LessThan(const E& left, const A& right) {
  if (left < right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail("expected: %s < %s", es.c_str(), as.c_str());
}

template<typename E, typename A>
void DynamicAssertionHelper::LessEqual(const E& left, const A& right) {
  if (left <= right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail("expected: %s <= %s", es.c_str(), as.c_str());
}

template<typename E, typename A>
void DynamicAssertionHelper::GreaterThan(const E& left, const A& right) {
  if (left > right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail("expected: %s > %s", es.c_str(), as.c_str());
}

template<typename E, typename A>
void DynamicAssertionHelper::GreaterEqual(const E& left, const A& right) {
  if (left >= right) return;
  std::stringstream ess, ass;
  ess << left;
  ass << right;
  std::string es = ess.str(), as = ass.str();
  Fail("expected: %s >= %s", es.c_str(), as.c_str());
}
#endif  // ifdef TESTING

}  // namespace fletch


#define FATAL(error) \
  fletch::Assert(__FILE__, __LINE__).Fail("%s", error)

#define FATAL1(format, p1) \
  fletch::Assert(__FILE__, __LINE__).Fail(format, (p1))

#define UNIMPLEMENTED() \
  FATAL("unimplemented code")

#define UNREACHABLE() \
  FATAL("unreachable code")

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

#define ASSERT(condition) \
  if (!(condition)) { \
    fletch::Assert(__FILE__, __LINE__).Fail("expected: %s", #condition); \
  }

#else  // if defined(DEBUG)

// In order to avoid variable unused warnings for code that only uses
// a variable in an ASSERT or EXPECT, we make sure to use the macro
// argument.
#define ASSERT(condition) while (false && (condition)) {}

#endif  // if defined(DEBUG)

#else  // if !defined(TESTING)
// TESTING is defined when building the test files. They do have a much wider
// variety of checks and error reporting available when compared to the normal
// runtime code. Also all of the checks are enabled for the tests themselves.
// The runtime code only has assertions enabled when running the debug test
// binaries.

#define ASSERT(condition) \
  if (!(condition)) { \
    fletch::Assert(__FILE__, __LINE__).Fail("expected: %s", #condition); \
  }

#define ASSERT_EQ(expected, actual) \
  fletch::Assert(__FILE__, __LINE__).Equals((expected), (actual))

#define ASSERT_STREQ(expected, actual) \
  fletch::Assert(__FILE__, __LINE__).StringEquals((expected), (actual))

#define ASSERT_LT(left, right) \
  fletch::Assert(__FILE__, __LINE__).LessThan((left), (right))

#define ASSERT_LE(left, right) \
  fletch::Assert(__FILE__, __LINE__).LessEqual((left), (right))

#define ASSERT_GT(left, right) \
  fletch::Assert(__FILE__, __LINE__).GreaterThan((left), (right))

#define ASSERT_GE(left, right) \
  fletch::Assert(__FILE__, __LINE__).GreaterEqual((left), (right))

#define EXPECT(condition) \
  if (!(condition)) { \
    fletch::Expect(__FILE__, __LINE__).Fail("expected: %s", #condition); \
  }

#define EXPECT_EQ(expected, actual) \
  fletch::Expect(__FILE__, __LINE__).Equals((expected), (actual))

#define EXPECT_STREQ(expected, actual) \
  fletch::Expect(__FILE__, __LINE__).StringEquals((expected), (actual))

#define EXPECT_LT(left, right) \
  fletch::Expect(__FILE__, __LINE__).LessThan((left), (right))

#define EXPECT_LE(left, right) \
  fletch::Expect(__FILE__, __LINE__).LessEqual((left), (right))

#define EXPECT_GT(left, right) \
  fletch::Expect(__FILE__, __LINE__).GreaterThan((left), (right))

#define EXPECT_GE(left, right) \
  fletch::Expect(__FILE__, __LINE__).GreaterEqual((left), (right))

#endif  // if !defined(TESTING)


#endif  // SRC_SHARED_ASSERT_H_
