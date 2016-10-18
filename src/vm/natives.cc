// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/natives.h"

#include <errno.h>
#include <math.h>
#include <stdlib.h>

#include "src/shared/bytecodes.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"
#include "src/shared/platform.h"

#include "src/vm/event_handler.h"
#include "src/vm/interpreter.h"
#include "src/vm/native_interpreter.h"
#include "src/vm/port.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/session.h"
#include "src/vm/unicode.h"

#include "third_party/double-conversion/src/double-conversion.h"

namespace dartino {

static const char kDoubleExponentChar = 'e';
static const char* kDoubleInfinitySymbol = "Infinity";
static const char* kDoubleNaNSymbol = "NaN";

static Object* ToBool(Process* process, bool value) {
  Program* program = process->program();
  return value ? program->true_object() : program->false_object();
}

#ifdef DEBUG
NativeVerifier::NativeVerifier(Process* process)
    : process_(process), allocation_count_(0) {
  process_->set_native_verifier(this);
}

NativeVerifier::~NativeVerifier() {
  // If you hit this assert you have a native that performs more than
  // one allocation.
  ASSERT(allocation_count_ <= 1);
  process_->set_native_verifier(NULL);
}
#endif

extern "C" Object* NativePrintToConsole(Process* process, Object* object) {
  object->ShortPrint();
  Print::Out("\n");
  return process->program()->null_object();
}

extern "C" Object* NativeExposeGC(Process* process) {
  return ToBool(process, Flags::expose_gc);
}

extern "C" Object* NativeGC(Process* process) {
#ifdef DEBUG
  // Return a retry_after_gc failure to force a process GC. On the retry return
  // null.
  if (process->TrueThenFalse()) return Failure::retry_after_gc(4);
#endif
  return process->program()->null_object();
}

extern "C" Object* NativeIntParse(Process* process, Object* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  char* chars = AsForeignString(x);
  if (chars == NULL) return Failure::wrong_argument_type();
  int length = strlen(chars);
  Smi* radix = Smi::cast(y);
  char* end = chars;
  int64 result = strtoll(chars, &end, radix->value());
  bool error = (end != chars + length) || (errno == ERANGE);
  free(chars);
  if (error) return Failure::index_out_of_bounds();
  return process->ToInteger(result);
}


extern "C" Object* NativeSmiToDouble(Process* process, Smi* x) {
  return process->NewDouble(static_cast<double>(x->value()));
}

extern "C" Object* NativeSmiToString(Process* process, Smi* x) {
  // We need kMaxSmiCharacters + 1 since we need to null terminate the string.
  char buffer[Smi::kMaxSmiCharacters + 1];
  int length = snprintf(buffer, ARRAY_SIZE(buffer), "%ld", x->value());
  ASSERT(length > 0 && length <= Smi::kMaxSmiCharacters);
  return process->NewStringFromAscii(List<const char>(buffer, length));
}

extern "C" Object* NativeSmiToMint(Process* process, Smi* x) {
  return process->NewInteger(x->value());
}

extern "C" Object* NativeSmiNegate(Process* process, Smi* x) {
  if (x->value() == Smi::kMinValue) return Failure::index_out_of_bounds();
  return Smi::FromWord(-x->value());
}

extern "C" Object* NativeSmiAdd(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word x_value = reinterpret_cast<word>(x);
  word y_value = reinterpret_cast<word>(y);
  word result;
  if (Utils::SignedAddOverflow(x_value, y_value, &result)) {
    // TODO(kasperl): Consider throwing a different error on overflow?
    return Failure::wrong_argument_type();
  }
  return reinterpret_cast<Smi*>(result);
}

extern "C" Object* NativeSmiSub(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word x_value = reinterpret_cast<word>(x);
  word y_value = reinterpret_cast<word>(y);
  word result;
  if (Utils::SignedSubOverflow(x_value, y_value, &result)) {
    // TODO(kasperl): Consider throwing a different error on overflow?
    return Failure::wrong_argument_type();
  }
  return reinterpret_cast<Smi*>(result);
}

extern "C" Object* NativeSmiMul(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word x_value = reinterpret_cast<word>(x);
  word y_value = Smi::cast(y)->value();
  word result;
  if (Utils::SignedMulOverflow(x_value, y_value, &result)) {
    // TODO(kasperl): Consider throwing a different error on overflow?
    return Failure::wrong_argument_type();
  }
  return reinterpret_cast<Smi*>(result);
}

extern "C" Object* NativeSmiMod(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  if (y_value == 0) return Failure::index_out_of_bounds();
  word result = x->value() % y_value;
  if (result < 0) result += (y_value > 0) ? y_value : -y_value;
  return Smi::FromWord(result);
}

extern "C" Object* NativeSmiDiv(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return process->NewDouble(static_cast<double>(x->value()) / y_value);
}

extern "C" Object* NativeSmiTruncDiv(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  if (y_value == 0) return Failure::index_out_of_bounds();
  word result = x->value() / y_value;
  if (!Smi::IsValid(result)) return Failure::wrong_argument_type();
  return Smi::FromWord(result);
}

extern "C" Object* NativeSmiBitNot(Process* process, Smi* x) {
  return Smi::FromWord(~x->value());
}

extern "C" Object* NativeSmiBitAnd(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return Smi::FromWord(x->value() & y_value);
}

extern "C" Object* NativeSmiBitOr(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return Smi::FromWord(x->value() | y_value);
}

extern "C" Object* NativeSmiBitXor(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return Smi::FromWord(x->value() ^ y_value);
}

extern "C" Object* NativeSmiBitShr(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  word x_value = x->value();
  // If the shift amount is larger than the word size we shift by the
  // word size minus 1. This is safe since Smis only use word-size minus
  // 1 bits in any case.
  word shift = (y_value >= kBitsPerWord) ? (kBitsPerWord - 1) : y_value;
  return Smi::FromWord(x_value >> shift);
}

extern "C" Object* NativeSmiBitShl(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  if (y_value >= kBitsPerPointer) return Failure::wrong_argument_type();
  word x_value = x->value();
  word result = x_value << y_value;
  bool overflow = !Smi::IsValid(result) || ((result >> y_value) != x_value);
  if (overflow) return Failure::wrong_argument_type();
  return Smi::FromWord(result);
}

extern "C" Object* NativeSmiEqual(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  return ToBool(process, x == y);
}

extern "C" Object* NativeSmiLess(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() < y_value);
}

extern "C" Object* NativeSmiLessEqual(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() <= y_value);
}

extern "C" Object* NativeSmiGreater(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() > y_value);
}

extern "C" Object* NativeSmiGreaterEqual(Process* process, Smi* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() >= y_value);
}

extern "C" Object* NativeMintToDouble(Process* process, LargeInteger* x) {
  return process->NewDouble(static_cast<double>(x->value()));
}

extern "C" Object* NativeMintToString(Process* process, LargeInteger* x) {
  long long int value = x->value();  // NOLINT
  char buffer[128];  // TODO(kasperl): What's the right buffer size?
  int length = snprintf(buffer, ARRAY_SIZE(buffer), "%lld", value);
  return process->NewStringFromAscii(List<const char>(buffer, length));
}

extern "C" Object* NativeMintNegate(Process* process, LargeInteger* x) {
  if (x->value() == INT64_MIN) return Failure::index_out_of_bounds();
  return process->NewInteger(-x->value());
}

extern "C" Object* NativeMintAdd(Process* process, LargeInteger* x, Object *y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  int64 result = x_value + y_value;
  if ((x_value < 0) != (y_value < 0) || (result < 0) == (x_value < 0)) {
    return process->ToInteger(result);
  }
  return Failure::index_out_of_bounds();
}

extern "C" Object* NativeMintSub(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  int64 result = x_value - y_value;
  if ((x_value < 0) == (y_value < 0) || (result < 0) == (x_value < 0)) {
    return process->ToInteger(result);
  }
  return Failure::index_out_of_bounds();
}

extern "C" Object* NativeMintMul(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  if (Utils::Signed64BitMulMightOverflow(x_value, y_value)) {
    return Failure::index_out_of_bounds();
  }
  return process->ToInteger(x_value * y_value);
}

extern "C" Object* NativeMintMod(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  if (y_value == 0) {
    return Failure::illegal_state();
  }
  int64 x_value = x->value();
  if (x_value != INT64_MIN || y_value != -1) {
    int64 result = x_value % y_value;
    if (result < 0) result += (y_value > 0) ? y_value : -y_value;
    return process->ToInteger(result);
  }
  return Failure::index_out_of_bounds();
}

extern "C" Object* NativeMintDiv(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->NewDouble(static_cast<double>(x->value()) / y_value);
}

extern "C" Object* NativeMintTruncDiv(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  if (y_value == 0) {
    return Failure::illegal_state();
  }
  int64 x_value = x->value();
  if (x_value != INT64_MIN || y_value != -1) {
    return process->ToInteger(x_value / y_value);
  }
  return Failure::index_out_of_bounds();
}

extern "C" Object* NativeMintBitNot(Process* process, LargeInteger* x) {
  return process->NewInteger(~x->value());
}

extern "C" Object* NativeMintBitAnd(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->ToInteger(x->value() & y_value);
}

extern "C" Object* NativeMintBitOr(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->ToInteger(x->value() | y_value);
}

extern "C" Object* NativeMintBitXor(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->ToInteger(x->value() ^ y_value);
}

extern "C" Object* NativeMintBitShr(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  // For values larger than or equal to 64 the shift will
  // misbehave and perform a shift with 'y_value % 64'.
  // Therefore, we deal with those cases explicitly here.
  if (y_value >= 64) {
    return process->ToInteger(x->value() < 0 ? -1 : 0);
  }
  return process->ToInteger(x->value() >> y_value);
}

extern "C" Object* NativeMintBitShl(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  int x_bit_length = Utils::BitLength(x_value);
  if (x_bit_length + y_value >= 64) {
    return Failure::index_out_of_bounds();
  }
  return process->ToInteger(x->value() << y_value);
}

extern "C" Object* NativeMintEqual(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() == y_value);
}

extern "C" Object* NativeMintLess(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() < y_value);
}

extern "C" Object* NativeMintLessEqual(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() <= y_value);
}

extern "C" Object* NativeMintGreater(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() > y_value);
}

extern "C" Object* NativeMintGreaterEqual(Process* process, LargeInteger* x, Object* y) {
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() >= y_value);
}

extern "C" Object* NativeDoubleNegate(Process* process, Double* x) {
  return process->NewDouble(-x->value());
}

extern "C" Object* NativeDoubleAdd(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() + y_value);
}

extern "C" Object* NativeDoubleSub(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() - y_value);
}

extern "C" Object* NativeDoubleMul(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() * y_value);
}

extern "C" Object* NativeDoubleMod(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(fmod(x->value(), y_value));
}

extern "C" Object* NativeDoubleDiv(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() / y_value);
}

extern "C" Object* NativeDoubleTruncDiv(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  if (y_value == 0) return Failure::index_out_of_bounds();
  return process->NewInteger(static_cast<int64>(x->value() / y_value));
}

extern "C" Object* NativeDoubleEqual(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() == y_value);
}

extern "C" Object* NativeDoubleLess(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() < y_value);
}

extern "C" Object* NativeDoubleLessEqual(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() <= y_value);
}

extern "C" Object* NativeDoubleGreater(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() > y_value);
}

extern "C" Object* NativeDoubleGreaterEqual(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() >= y_value);
}

extern "C" Object* NativeDoubleIsNaN(Process* process, Double* x) {
  dartino_double d = x->value();
  return ToBool(process, isnan(static_cast<double>(d)));
}

extern "C" Object* NativeDoubleIsNegative(Process* process, Double* x) {
  // TODO(ajohnsen): Okay to always use double version?
  double d = static_cast<double>(x->value());
  return ToBool(process, (signbit(d) != 0) && !isnan(d));
}

extern "C" Object* NativeDoubleCeil(Process* process, Double* x) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(x->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(ceil(value)));
}

extern "C" Object* NativeDoubleCeilToDouble(Process* process, Double* x) {
  return process->NewDouble(ceil(x->value()));
}

extern "C" Object* NativeDoubleRound(Process* process, Double* x) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(x->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(round(value)));
}

extern "C" Object* NativeDoubleRoundToDouble(Process* process, Double* x) {
  return process->NewDouble(round(x->value()));
}

extern "C" Object* NativeDoubleFloor(Process* process, Double* x) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(x->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(floor(value)));
}

extern "C" Object* NativeDoubleFloorToDouble(Process* process, Double* x) {
  return process->NewDouble(floor(x->value()));
}

extern "C" Object* NativeDoubleTruncate(Process* process, Double* x) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(x->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(trunc(value)));
}

extern "C" Object* NativeDoubleTruncateToDouble(Process* process, Double* x) {
  return process->NewDouble(trunc(x->value()));
}

extern "C" Object* NativeDoubleRemainder(Process* process, Double* x, Object* y) {
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  Double* yd = Double::cast(y);
  return process->NewDouble(fmod(x->value(), yd->value()));
}

extern "C" Object* NativeDoubleToInt(Process* process, Double* x) {
  // TODO(ajohnsen): Okay to always use double version?
  double d = static_cast<double>(x->value());
  if (isinf(d) || isnan(d)) return Failure::index_out_of_bounds();
  // TODO(ager): Handle large doubles that are out of int64 range.
  int64 result = static_cast<int64>(trunc(d));
  return process->ToInteger(result);
}

extern "C" Object* NativeDoubleToString(Process* process, Double* d) {
  static const int kDecimalLow = -6;
  static const int kDecimalHigh = 21;
  static const int kBufferSize = 128;

  char buffer[kBufferSize] = {'\0'};

  // The output contains the sign, at most kDecimalHigh - 1 digits,
  // the decimal point followed by a 0 plus the \0.
  ASSERT(kBufferSize >= 1 + (kDecimalHigh - 1) + 1 + 1 + 1);
  // Or it contains the sign, a 0, the decimal point, kDecimalLow '0's,
  // 17 digits (the precision needed for doubles), plus the \0.
  ASSERT(kBufferSize >= 1 + 1 + 1 + kDecimalLow + 17 + 1);
  // Alternatively it contains a sign, at most 17 digits (precision needed for
  // any double), the decimal point, the exponent character, the exponent's
  // sign, at most three exponent digits, plus the \0.
  ASSERT(kBufferSize >= 1 + 17 + 1 + 1 + 1 + 3 + 1);

  static const int kConversionFlags =
      double_conversion::DoubleToStringConverter::EMIT_POSITIVE_EXPONENT_SIGN |
      double_conversion::DoubleToStringConverter::EMIT_TRAILING_DECIMAL_POINT |
      double_conversion::DoubleToStringConverter::
          EMIT_TRAILING_ZERO_AFTER_POINT;

  const double_conversion::DoubleToStringConverter converter(
      kConversionFlags, kDoubleInfinitySymbol, kDoubleNaNSymbol,
      kDoubleExponentChar, kDecimalLow, kDecimalHigh, 0,
      0);  // Last two values are ignored in shortest mode.

  double_conversion::StringBuilder builder(buffer, kBufferSize);
  bool status = converter.ToShortest(d->value(), &builder);
  ASSERT(status);
  char* result = builder.Finalize();
  ASSERT(result == buffer);
  return process->NewStringFromAscii(List<const char>(result, strlen(result)));
}

extern "C" Object* NativeDoubleToStringAsExponential(Process* process, Double* x, Smi* y) {
  static const int kBufferSize = 128;

  double d = x->value();
  int digits = y->value();
  ASSERT(-1 <= digits && digits <= 20);

  const double_conversion::DoubleToStringConverter converter(
      double_conversion::DoubleToStringConverter::EMIT_POSITIVE_EXPONENT_SIGN,
      kDoubleInfinitySymbol, kDoubleNaNSymbol, kDoubleExponentChar, 0, 0, 0,
      0);  // Last four values are ignored in exponential mode.

  char buffer[kBufferSize] = {'\0'};
  double_conversion::StringBuilder builder(buffer, kBufferSize);
  bool status = converter.ToExponential(d, digits, &builder);
  ASSERT(status);
  char* result = builder.Finalize();
  ASSERT(result == buffer);
  return process->NewStringFromAscii(List<const char>(result, strlen(result)));
}

extern "C" Object* NativeDoubleToStringAsFixed(Process* process, Double* x, Smi* y) {
  static const int kBufferSize = 128;

  double d = x->value();
  ASSERT(-1e21 <= d && d <= 1e21);
  int digits = y->value();
  ASSERT(0 <= digits && digits <= 20);

  const double_conversion::DoubleToStringConverter converter(
      double_conversion::DoubleToStringConverter::NO_FLAGS,
      kDoubleInfinitySymbol, kDoubleNaNSymbol, kDoubleExponentChar, 0, 0, 0,
      0);  // Last four values are ignored in fixed mode.

  char buffer[kBufferSize] = {'\0'};
  double_conversion::StringBuilder builder(buffer, kBufferSize);
  bool status = converter.ToFixed(d, digits, &builder);
  ASSERT(status);
  char* result = builder.Finalize();
  ASSERT(result == buffer);
  return process->NewStringFromAscii(List<const char>(result, strlen(result)));
}

extern "C" Object* NativeDoubleToStringAsPrecision(Process* process, Double* x, Smi* y) {
  static const int kBufferSize = 128;
  static const int kMaxLeadingPaddingZeroes = 6;
  static const int kMaxTrailingPaddingZeroes = 0;

  double d = x->value();
  int digits = y->value();
  ASSERT(1 <= digits && digits <= 21);

  const double_conversion::DoubleToStringConverter converter(
      double_conversion::DoubleToStringConverter::EMIT_POSITIVE_EXPONENT_SIGN,
      kDoubleInfinitySymbol, kDoubleNaNSymbol, kDoubleExponentChar, 0,
      0,  // Ignored in precision mode.
      kMaxLeadingPaddingZeroes, kMaxTrailingPaddingZeroes);

  char buffer[kBufferSize] = {'\0'};
  double_conversion::StringBuilder builder(buffer, kBufferSize);
  bool status = converter.ToPrecision(d, digits, &builder);
  ASSERT(status);
  char* result = builder.Finalize();
  ASSERT(result == buffer);
  return process->NewStringFromAscii(List<const char>(result, strlen(result)));
}

extern "C" Object* NativeDoubleParse(Process* process, Object* x) {
  // We trim in Dart to handle all the whitespaces.
  static const int kConversionFlags =
      double_conversion::StringToDoubleConverter::NO_FLAGS;

  double_conversion::StringToDoubleConverter converter(
      kConversionFlags, 0.0, 0.0, kDoubleInfinitySymbol, kDoubleNaNSymbol);

  int length = 0;
  int consumed = 0;
  double result = 0.0;
  if (x->IsOneByteString()) {
    OneByteString* source = OneByteString::cast(x);
    length = source->length();
    char* buffer = reinterpret_cast<char*>(source->byte_address_for(0));
    result = converter.StringToDouble(buffer, length, &consumed);
  } else if (x->IsTwoByteString()) {
    TwoByteString* source = TwoByteString::cast(x);
    length = source->length();
    uint16* buffer = reinterpret_cast<uint16_t*>(source->byte_address_for(0));
    result = converter.StringToDouble(buffer, length, &consumed);
  } else {
    return Failure::wrong_argument_type();
  }

  // The string is trimmed, so we must accept the full string.
  if (consumed != length) return Failure::index_out_of_bounds();
  return process->NewDouble(result);
}

#define DOUBLE_MATH_NATIVE(name, method)                         \
  extern "C" Object* Native##name(Process* process, Object* x) { \
    if (!x->IsDouble()) return Failure::wrong_argument_type();   \
    dartino_double d = Double::cast(x)->value();                 \
    return process->NewDouble(method(d));                        \
  }

DOUBLE_MATH_NATIVE(DoubleSin, sin)
DOUBLE_MATH_NATIVE(DoubleCos, cos)
DOUBLE_MATH_NATIVE(DoubleTan, tan)
DOUBLE_MATH_NATIVE(DoubleAcos, acos)
DOUBLE_MATH_NATIVE(DoubleAsin, asin)
DOUBLE_MATH_NATIVE(DoubleAtan, atan)
DOUBLE_MATH_NATIVE(DoubleSqrt, sqrt)
DOUBLE_MATH_NATIVE(DoubleExp, exp)
DOUBLE_MATH_NATIVE(DoubleLog, log)

extern "C" Object* NativeDoubleAtan2(Process* process, Object* x, Object* y) {
  if (!x->IsDouble()) return Failure::wrong_argument_type();
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double x_value = Double::cast(x)->value();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(atan2(x_value, y_value));
}

extern "C" Object* NativeDoublePow(Process* process, Object* x, Object* y) {
  if (!x->IsDouble()) return Failure::wrong_argument_type();
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double x_value = Double::cast(x)->value();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(pow(x_value, y_value));
}

extern "C" Object* NativeListNew(Process* process, Object* x) {
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int length = Smi::cast(x)->value();
  if (length < 0) return Failure::index_out_of_bounds();
  return process->NewArray(length);
}

extern "C" Object* NativeListLength(Process* process, Instance* instance) {
  Object* list = instance->GetInstanceField(0);
  return Smi::FromWord(BaseArray::cast(list)->length());
}

extern "C" Object* NativeListIndexGet(Process* process, Instance* instance, Object* x) {
  Object* list = instance->GetInstanceField(0);
  Array* array = Array::cast(list);
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int index = Smi::cast(x)->value();
  if (index < 0 || index >= array->length()) {
    return Failure::index_out_of_bounds();
  }
  return array->get(index);
}

extern "C" Object* NativeByteListIndexGet(Process* process, Instance* instance, Object* x) {
  Object* list = instance->GetInstanceField(0);
  ByteArray* array = ByteArray::cast(list);
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int index = Smi::cast(x)->value();
  if (index < 0 || index >= array->length()) {
    return Failure::index_out_of_bounds();
  }
  return Smi::FromWord(array->get(index));
}

extern "C" Object* NativeListIndexSet(Process* process, Instance* instance, Object* x, Object* value) {
  Object* list = instance->GetInstanceField(0);
  Array* array = Array::cast(list);
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int index = Smi::cast(x)->value();
  if (index < 0 || index >= array->length()) {
    return Failure::index_out_of_bounds();
  }
  array->set(index, value);
  process->RecordStore(array, value);
  return value;
}

extern "C" Object* NativeArgumentsLength(Process* process) {
  return process->ToInteger(process->arguments().length());
}

extern "C" Object* NativeArgumentsToString(Process* process, Object* x) {
  word index = AsForeignWord(x);
  List<uint8> data = process->arguments()[index];

  uint8_t* utf8 = data.data();
  int utf8_length = data.length();
  Utf8::Type type;
  int utf16_length = Utf8::CodeUnitCount(utf8, utf8_length, &type);

  Object* object = process->NewTwoByteString(utf16_length);
  if (object->IsRetryAfterGCFailure()) return object;
  TwoByteString* str = TwoByteString::cast(object);

  uint16* utf16 = reinterpret_cast<uint16*>(str->byte_address_for(0));
  Utf8::DecodeToUTF16(utf8, utf8_length, utf16, utf16_length);

  return str;
}

static Function* FunctionForClosure(Object* argument, unsigned arity) {
  Instance* closure = Instance::cast(argument);
  Class* closure_class = closure->get_class();
  word selector = Selector::EncodeMethod(Names::kCall, arity);
  return closure_class->LookupMethod(selector);
}

static Process* SpawnProcessInternal(Program* program, Process* process,
                                     Instance* entrypoint, Instance* closure,
                                     Object* argument) {
  Function* entry = FunctionForClosure(entrypoint, 2);
  ASSERT(entry != NULL);

  // Code in process spawning generally assumes there is enough space for
  // stacks etc.  We use a [NoAllocationFailureScope] to ensure it.
  NoAllocationFailureScope scope(program->process_heap()->space());

  // Spawn a new process and create a copy of the closure in the
  // new process' heap.
  Process* child = program->SpawnProcess(process);

  // Set up the stack as a call of the entry with one argument: closure.
  child->SetupExecutionStack();
  Stack* stack = child->stack();
  uint8_t* bcp = entry->bytecode_address_for(0);
  // The entry closure takes three arguments, 'this', the closure, and
  // a single argument. Since the method is a static tear-off, 'this'
  // is not used and simply be 'NULL'.
  word top = stack->length();
  stack->set(--top, NULL);
  stack->set(--top, NULL);
  Object** frame_pointer = stack->Pointer(top);
  stack->set(--top, NULL);
  stack->set(--top, NULL);
  stack->set(--top, closure);
  stack->set(--top, argument);
  // Push empty slot, fp and bcp.
  stack->set(--top, NULL);
  stack->set(--top, reinterpret_cast<Object*>(frame_pointer));
  frame_pointer = stack->Pointer(top);
  stack->set(--top, reinterpret_cast<Object*>(bcp));
  // Finally push the entry and fp.
  //TODO(dmitryolsh): figure out how to implement this in LLVM.  
  stack->set_top(top);

  return child;
}

extern "C" Object* NativeProcessSpawn(Process* process, Instance* entrypoint, Instance* closure,
    Object* argument, Object* to_child, Object* from_child, Object* dart_monitor_port) {
  Program* program = process->program();

  bool link_to_child = to_child == program->true_object();
  bool link_from_child = from_child == program->true_object();
  Port* monitor_port = NULL;
  if (!dart_monitor_port->IsNull()) {
    if (!dart_monitor_port->IsPort()) {
      return Failure::wrong_argument_type();
    }
    monitor_port = Port::FromDartObject(dart_monitor_port);
  }

  if (!closure->IsImmutable()) {
    // TODO(kasperl): Return a proper failure.
    return Failure::index_out_of_bounds();
  }

  bool has_argument = !argument->IsNull();
  if (has_argument && !argument->IsImmutable()) {
    // TODO(kasperl): Return a proper failure.
    return Failure::index_out_of_bounds();
  }

  if (FunctionForClosure(closure, has_argument ? 1 : 0) == NULL) {
    // TODO(kasperl): Return a proper failure.
    return Failure::index_out_of_bounds();
  }

  Object* dart_process = process->NewInstance(program->process_class(), true);
  if (dart_process->IsRetryAfterGCFailure()) return dart_process;

  Process* child =
      SpawnProcessInternal(program, process, entrypoint, closure, argument);

  ProcessHandle* handle = child->process_handle();
  handle->IncrementRef();

  handle->InitializeDartObject(dart_process);
  process->RegisterFinalizer(HeapObject::cast(dart_process),
                             Process::FinalizeProcess);

  if (link_to_child) {
    process->links()->InsertHandle(child->process_handle());
  }
  if (link_from_child) {
    child->links()->InsertHandle(process->process_handle());
  }

  if (monitor_port != NULL) {
    child->links()->InsertPort(monitor_port);
  }

  program->scheduler()->EnqueueProcessOnSchedulerWorkerThread(process, child);

  return dart_process;
}

extern "C" Object* NativeProcessCurrent(Process* process) {
  Program* program = process->program();
  ProcessHandle* handle = process->process_handle();

  Object* dart_process = process->NewInstance(program->process_class(), true);
  if (dart_process->IsRetryAfterGCFailure()) return dart_process;
  handle->InitializeDartObject(dart_process);

  return dart_process;
}


extern "C" Object* NativeCoroutineCurrent(Process* process) { return process->coroutine(); }

extern "C" Object* NativeCoroutineNewStack(Process* process, Instance* coroutine, Instance* entry) {
  Object* object = process->NewStack(256);
  if (object->IsFailure()) return object;

  // TODO(kasperl): Avoid repeated lookups. Cache the start
  // function in the program?
  int selector = Selector::Encode(Names::kCoroutineStart, Selector::METHOD, 1);
  Function* start = coroutine->get_class()->LookupMethod(selector);
  ASSERT(start->arity() == 2);

  uint8* bcp = start->bytecode_address_for(0);
  ASSERT(bcp[0] == kLoadLiteral0);
  ASSERT(bcp[1] == kLoadLiteral0);
  ASSERT(bcp[2] == kCoroutineChange);

  Stack* stack = Stack::cast(object);
  word top = stack->length();
  stack->set(--top, NULL);
  stack->set(--top, NULL);
  Object** frame_pointer = stack->Pointer(top);
  stack->set(--top, NULL);
  stack->set(--top, coroutine);
  stack->set(--top, entry);
  // Push empty slot, fp and bcp.
  stack->set(--top, NULL);
  stack->set(--top, reinterpret_cast<Object*>(frame_pointer));
  frame_pointer = stack->Pointer(top);
  stack->set(--top, reinterpret_cast<Object*>(bcp + 2));
  stack->set(--top, Smi::FromWord(0));  // Fake 'stack' argument.
  stack->set(--top, Smi::FromWord(0));  // Fake 'value' argument.
  // Leave bcp at the kChangeStack instruction to make it look like a
  // suspended co-routine. bcp is incremented on resume.
  //TODO(dmitryolsh): figure out how to implement this in LLVM.
  stack->set_top(top);
  return stack;
}

extern "C" Object* NativeStopwatchFrequency(Process* process) {
  return Smi::FromWord(1000000);
}

extern "C" Object* NativeStopwatchNow(Process* process) {
  static uint64 first = 0;
  uint64 now = Platform::GetProcessMicroseconds();
  if (first == 0) first = now;
  return process->ToInteger(now - first);
}

extern "C" Object* NativeIdentityHashCode(Process* process, Object* object) {
  if (object->IsOneByteString()) {
    return Smi::FromWord(OneByteString::cast(object)->Hash());
  } else if (object->IsTwoByteString()) {
    return Smi::FromWord(TwoByteString::cast(object)->Hash());
  } else if (object->IsSmi() || object->IsLargeInteger()) {
    return object;
  } else if (object->IsDouble()) {
    dartino_double value = Double::cast(object)->value();
    return process->ToInteger(static_cast<int64>(value));
  } else {
    return Instance::cast(object)->LazyIdentityHashCode(process->random());
  }
}

char* AsForeignString(Object* object) {
  if (object->IsOneByteString()) {
    return OneByteString::cast(object)->ToCString();
  }
  if (object->IsTwoByteString()) {
    return TwoByteString::cast(object)->ToCString();
  }
  return NULL;
}

extern "C" Object* NativeStringLength(Process* process, BaseArray* x) {
  return Smi::FromWord(x->length());
}

extern "C" Object* NativeOneByteStringAdd(Process* process, OneByteString* x, Object* other) {
  if (!other->IsString()) return Failure::wrong_argument_type();

  int xlen = x->length();
  if (xlen == 0) return other;

  if (other->IsOneByteString()) {
    OneByteString* y = OneByteString::cast(other);
    int ylen = y->length();
    if (ylen == 0) return x;
    int length = xlen + ylen;
    Object* raw_result = process->NewOneByteStringUninitialized(length);
    if (raw_result->IsFailure()) return raw_result;
    OneByteString* result = OneByteString::cast(raw_result);
    result->FillFrom(x, 0);
    result->FillFrom(y, xlen);
    return result;
  }

  ASSERT(other->IsTwoByteString());
  TwoByteString* y = TwoByteString::cast(other);
  int ylen = y->length();
  if (ylen == 0) return x;
  int length = xlen + ylen;
  Object* raw_result = process->NewTwoByteStringUninitialized(length);
  if (raw_result->IsFailure()) return raw_result;
  TwoByteString* result = TwoByteString::cast(raw_result);
  result->FillFrom(x, 0);
  result->FillFrom(y, xlen);
  return result;
}

extern "C" Object* NativeOneByteStringCodeUnitAt(Process* process, OneByteString* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  if (index >= x->length()) return Failure::index_out_of_bounds();
  return process->ToInteger(x->get_char_code(index));
}

extern "C" Object* NativeOneByteStringCreate(Process* process, Object* z) {
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word length = Smi::cast(z)->value();
  if (length < 0) return Failure::index_out_of_bounds();
  Object* result = process->NewOneByteString(length);
  return result;
}

extern "C" Object* NativeOneByteStringEqual(Process* process, OneByteString* x, Object* y) {
  if (y->IsOneByteString()) {
    return ToBool(process, x->Equals(OneByteString::cast(y)));
  }

  if (y->IsTwoByteString()) {
    return ToBool(process, x->Equals(TwoByteString::cast(y)));
  }

  return process->program()->false_object();
}

extern "C" Object* NativeOneByteStringSetCodeUnitAt(Process* process, OneByteString* x, Object* y, Object* z) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word value = Smi::cast(z)->value();
  if (value < 0 || value > 65535) return Failure::wrong_argument_type();
  x->set_char_code(index, value);
  return process->program()->null_object();
}

extern "C" Object* NativeOneByteStringSetContent(Process* process, OneByteString* x, Smi* offset, Object* other) {
  if (!other->IsOneByteString()) return Failure::wrong_argument_type();

  OneByteString* y = OneByteString::cast(other);
  x->FillFrom(y, offset->value());
  return process->program()->null_object();
}

extern "C" Object* NativeOneByteStringSubstring(Process* process, OneByteString* x, Object* y, Object* z) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word start = Smi::cast(y)->value();
  word end = Smi::cast(z)->value();
  if (start < 0) return Failure::index_out_of_bounds();
  if (end < start) return Failure::index_out_of_bounds();
  int length = x->length();
  if (end > length) return Failure::index_out_of_bounds();
  if (start == 0 && end == length) return x;
  int substring_length = end - start;
  int data_size = substring_length;
  Object* raw_string = process->NewOneByteStringUninitialized(substring_length);
  if (raw_string->IsFailure()) return raw_string;
  OneByteString* result = OneByteString::cast(raw_string);
  memcpy(result->byte_address_for(0), x->byte_address_for(start), data_size);
  return result;
}

extern "C" Object* NativeTwoByteStringLength(Process* process, TwoByteString* x) {
  return Smi::FromWord(x->length());
}

extern "C" Object* NativeTwoByteStringAdd(Process* process, TwoByteString* x, Object* other) {
  if (!other->IsString()) return Failure::wrong_argument_type();

  int xlen = x->length();
  if (xlen == 0) return other;

  if (other->IsOneByteString()) {
    OneByteString* y = OneByteString::cast(other);
    int ylen = y->length();
    if (ylen == 0) return x;
    int length = xlen + ylen;
    Object* raw_result = process->NewTwoByteStringUninitialized(length);
    if (raw_result->IsFailure()) return raw_result;
    TwoByteString* result = TwoByteString::cast(raw_result);
    result->FillFrom(x, 0);
    result->FillFrom(y, xlen);
    return result;
  }

  ASSERT(other->IsTwoByteString());

  TwoByteString* y = TwoByteString::cast(other);
  int ylen = y->length();
  if (ylen == 0) return x;
  int length = xlen + ylen;
  Object* raw_result = process->NewTwoByteStringUninitialized(length);
  if (raw_result->IsFailure()) return raw_result;
  TwoByteString* result = TwoByteString::cast(raw_result);
  result->FillFrom(x, 0);
  result->FillFrom(y, xlen);
  return result;
}

extern "C" Object* NativeTwoByteStringCodeUnitAt(Process* process, TwoByteString* x, Object* y) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  if (index >= x->length()) return Failure::index_out_of_bounds();
  return process->ToInteger(x->get_code_unit(index));
}

extern "C" Object* NativeTwoByteStringCreate(Process* process, Object* z) {
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word length = Smi::cast(z)->value();
  if (length < 0) return Failure::index_out_of_bounds();
  Object* result = process->NewTwoByteString(length);
  return result;
}

extern "C" Object* NativeTwoByteStringEqual(Process* process, TwoByteString* x, Object* y) {
  if (y->IsOneByteString()) {
    return ToBool(process, OneByteString::cast(y)->Equals(x));
  }

  if (y->IsTwoByteString()) {
    return ToBool(process, x->Equals(TwoByteString::cast(y)));
  }

  return process->program()->false_object();
}

extern "C" Object* NativeTwoByteStringSetCodeUnitAt(Process* process, TwoByteString* x, Object* y, Object* z) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word value = Smi::cast(z)->value();
  if (value < 0 || value > 65535) return Failure::wrong_argument_type();
  x->set_code_unit(index, value);
  return process->program()->null_object();
}

extern "C" Object* NativeTwoByteStringSetContent(Process* process, TwoByteString* x, Smi* offset, Object* other) {
  if (other->IsOneByteString()) {
    OneByteString* y = OneByteString::cast(other);
    x->FillFrom(y, offset->value());
    return process->program()->null_object();
  }

  if (other->IsTwoByteString()) {
    TwoByteString* y = TwoByteString::cast(other);
    x->FillFrom(y, offset->value());
    return process->program()->null_object();
  }

  return Failure::wrong_argument_type();
}

extern "C" Object* NativeTwoByteStringSubstring(Process* process, TwoByteString* x, Object* y, Object* z) {
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word start = Smi::cast(y)->value();
  word end = Smi::cast(z)->value();
  if (start < 0) return Failure::index_out_of_bounds();
  if (end < start) return Failure::index_out_of_bounds();
  int length = x->length();
  if (end > length) return Failure::index_out_of_bounds();
  if (start == 0 && end == length) return x;
  int substring_length = end - start;
  int data_size = substring_length * sizeof(uint16_t);
  Object* raw_string = process->NewTwoByteStringUninitialized(substring_length);
  if (raw_string->IsFailure()) return raw_string;
  TwoByteString* result = TwoByteString::cast(raw_string);
  memcpy(result->byte_address_for(0), x->byte_address_for(start), data_size);
  return result;
}

extern "C" Object* NativeDateTimeGetCurrentMs(Process* process) {
  uint64 us = Platform::GetMicroseconds();
  return process->ToInteger(us / 1000);
}

static int64 kMaxTimeZoneOffsetSeconds = 2100000000;

extern "C" Object* NativeDateTimeTimeZone(Process* process, Object* x) {
  word seconds = AsForeignWord(x);
  if (seconds < 0 || seconds > kMaxTimeZoneOffsetSeconds) {
    return Failure::index_out_of_bounds();
  }
  const char* name = Platform::GetTimeZoneName(seconds);
  return process->NewStringFromAscii(List<const char>(name, strlen(name)));
}

extern "C" Object* NativeDateTimeTimeZoneOffset(Process* process, Object* x) {
  word seconds = AsForeignWord(x);
  if (seconds < 0 || seconds > kMaxTimeZoneOffsetSeconds) {
    return Failure::index_out_of_bounds();
  }
  int offset = Platform::GetTimeZoneOffset(seconds);
  return process->ToInteger(offset);
}

extern "C" Object* NativeDateTimeLocalTimeZoneOffset(Process* process) {
  int offset = Platform::GetLocalTimeZoneOffset();
  return process->ToInteger(offset);
}

extern "C" Object* NativeSystemEventHandlerAdd(Process* process, Object* id, Object* port_arg, Object* flags_arg) {
  if (!port_arg->IsPort()) {
    return Failure::wrong_argument_type();
  }
  Port* port = Port::FromDartObject(port_arg);
  if (!flags_arg->IsSmi()) return Failure::wrong_argument_type();
  int flags = Smi::cast(flags_arg)->value();
  return EventHandler::GlobalInstance()->Add(process, id, port, flags);
}

extern "C" Object* NativeIsImmutable(Process* process, Object* o) {
  return ToBool(process, o->IsImmutable());
}

extern "C" Object* NativeUint32DigitsAllocate(Process* process, Smi* length) {
  word byte_size = length->value() * 4;
  return process->NewByteArray(byte_size);
}

extern "C" Object* NativeUint32DigitsGet(Process* process, ByteArray* backing, Smi* index) {
  word byte_index = index->value() * 4;
  ASSERT(byte_index + 4 <= backing->length());
  uint8* byte_address = backing->byte_address_for(byte_index);
  return process->ToInteger(*reinterpret_cast<uint32*>(byte_address));
}

extern "C" Object* NativeUint32DigitsSet(Process* process, ByteArray* backing, Smi* index, Object* object) {
  word byte_index = index->value() * 4;
  ASSERT(byte_index + 4 <= backing->length());
  uint8* byte_address = backing->byte_address_for(byte_index);
  uint32 value = object->IsSmi() ? Smi::cast(object)->value()
                                 : LargeInteger::cast(object)->value();
  *reinterpret_cast<uint32*>(byte_address) = value;
  return process->program()->null_object();
}

extern "C" Object* NativeTimerScheduleTimeout(Process* process, Object * x, Object* y) {
  int64 timeout = AsForeignInt64(x);
  Port* port = Port::FromDartObject(y);
  EventHandler::GlobalInstance()->ScheduleTimeout(timeout, port);
  return process->program()->null_object();
}

extern "C" Object* NativeEventHandlerSleep(Process* process, Object* x, Object* port_arg) {
  int64 arg = AsForeignInt64(x);
  // Adding one (1) if the sleep is not for 0 ms. This ensures that the
  // sleep will last at least the provided number of milliseconds.
  int64 offset = arg == 0 ? 0 : 1;
  int64 timeout = arg + Platform::GetMicroseconds() / 1000 + offset;
  Port* port = Port::FromDartObject(port_arg);
  EventHandler::GlobalInstance()->ScheduleTimeout(timeout, port);
  return process->program()->null_object();
}

}  // namespace dartino
