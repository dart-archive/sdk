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

BEGIN_NATIVE(PrintToConsole) {
  arguments[0]->ShortPrint();
  Print::Out("\n");
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(ExposeGC) { return ToBool(process, Flags::expose_gc); }
END_NATIVE()

BEGIN_NATIVE(GC) {
#ifdef DEBUG
  // Return a retry_after_gc failure to force a process GC. On the retry return
  // null.
  if (process->TrueThenFalse()) return Failure::retry_after_gc(4);
#endif
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(IntParse) {
  Object* x = arguments[0];
  Object* y = arguments[1];
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
END_NATIVE()

BEGIN_NATIVE(SmiToDouble) {
  Smi* x = Smi::cast(arguments[0]);
  return process->NewDouble(static_cast<double>(x->value()));
}
END_NATIVE()

BEGIN_NATIVE(SmiToString) {
  Smi* x = Smi::cast(arguments[0]);
  // We need kMaxSmiCharacters + 1 since we need to null terminate the string.
  char buffer[Smi::kMaxSmiCharacters + 1];
  int length = snprintf(buffer, ARRAY_SIZE(buffer), "%ld", x->value());
  ASSERT(length > 0 && length <= Smi::kMaxSmiCharacters);
  return process->NewStringFromAscii(List<const char>(buffer, length));
}
END_NATIVE()

BEGIN_NATIVE(SmiToMint) {
  Smi* x = Smi::cast(arguments[0]);
  return process->NewInteger(x->value());
}
END_NATIVE()

BEGIN_NATIVE(SmiNegate) {
  Smi* x = Smi::cast(arguments[0]);
  if (x->value() == Smi::kMinValue) return Failure::index_out_of_bounds();
  return Smi::FromWord(-x->value());
}
END_NATIVE()

BEGIN_NATIVE(SmiAdd) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
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
END_NATIVE()

BEGIN_NATIVE(SmiSub) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
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
END_NATIVE()

BEGIN_NATIVE(SmiMul) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
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
END_NATIVE()

BEGIN_NATIVE(SmiMod) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  if (y_value == 0) return Failure::index_out_of_bounds();
  word result = x->value() % y_value;
  if (result < 0) result += (y_value > 0) ? y_value : -y_value;
  return Smi::FromWord(result);
}
END_NATIVE()

BEGIN_NATIVE(SmiDiv) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return process->NewDouble(static_cast<double>(x->value()) / y_value);
}
END_NATIVE()

BEGIN_NATIVE(SmiTruncDiv) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  if (y_value == 0) return Failure::index_out_of_bounds();
  word result = x->value() / y_value;
  if (!Smi::IsValid(result)) return Failure::wrong_argument_type();
  return Smi::FromWord(result);
}
END_NATIVE()

BEGIN_NATIVE(SmiBitNot) {
  Smi* x = Smi::cast(arguments[0]);
  return Smi::FromWord(~x->value());
}
END_NATIVE()

BEGIN_NATIVE(SmiBitAnd) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return Smi::FromWord(x->value() & y_value);
}
END_NATIVE()

BEGIN_NATIVE(SmiBitOr) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return Smi::FromWord(x->value() | y_value);
}
END_NATIVE()

BEGIN_NATIVE(SmiBitXor) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return Smi::FromWord(x->value() ^ y_value);
}
END_NATIVE()

BEGIN_NATIVE(SmiBitShr) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  word x_value = x->value();
  // If the shift amount is larger than the word size we shift by the
  // word size minus 1. This is safe since Smis only use word-size minus
  // 1 bits in any case.
  word shift = (y_value >= kBitsPerWord) ? (kBitsPerWord - 1) : y_value;
  return Smi::FromWord(x_value >> shift);
}
END_NATIVE()

BEGIN_NATIVE(SmiBitShl) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  if (y_value >= kBitsPerPointer) return Failure::wrong_argument_type();
  word x_value = x->value();
  word result = x_value << y_value;
  bool overflow = !Smi::IsValid(result) || ((result >> y_value) != x_value);
  if (overflow) return Failure::wrong_argument_type();
  return Smi::FromWord(result);
}
END_NATIVE()

BEGIN_NATIVE(SmiEqual) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  return ToBool(process, x == y);
}
END_NATIVE()

BEGIN_NATIVE(SmiLess) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() < y_value);
}
END_NATIVE()

BEGIN_NATIVE(SmiLessEqual) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() <= y_value);
}
END_NATIVE()

BEGIN_NATIVE(SmiGreater) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() > y_value);
}
END_NATIVE()

BEGIN_NATIVE(SmiGreaterEqual) {
  Smi* x = Smi::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word y_value = Smi::cast(y)->value();
  return ToBool(process, x->value() >= y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintToDouble) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  return process->NewDouble(static_cast<double>(x->value()));
}
END_NATIVE()

BEGIN_NATIVE(MintToString) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  long long int value = x->value();  // NOLINT
  char buffer[128];  // TODO(kasperl): What's the right buffer size?
  int length = snprintf(buffer, ARRAY_SIZE(buffer), "%lld", value);
  return process->NewStringFromAscii(List<const char>(buffer, length));
}
END_NATIVE()

BEGIN_NATIVE(MintNegate) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  if (x->value() == INT64_MIN) return Failure::index_out_of_bounds();
  return process->NewInteger(-x->value());
}
END_NATIVE()

BEGIN_NATIVE(MintAdd) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  int64 result = x_value + y_value;
  if ((x_value < 0) != (y_value < 0) || (result < 0) == (x_value < 0)) {
    return process->ToInteger(result);
  }
  return Failure::index_out_of_bounds();
}
END_NATIVE()

BEGIN_NATIVE(MintSub) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  int64 result = x_value - y_value;
  if ((x_value < 0) == (y_value < 0) || (result < 0) == (x_value < 0)) {
    return process->ToInteger(result);
  }
  return Failure::index_out_of_bounds();
}
END_NATIVE()

BEGIN_NATIVE(MintMul) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  if (Utils::Signed64BitMulMightOverflow(x_value, y_value)) {
    return Failure::index_out_of_bounds();
  }
  return process->ToInteger(x_value * y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintMod) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
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
END_NATIVE()

BEGIN_NATIVE(MintDiv) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->NewDouble(static_cast<double>(x->value()) / y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintTruncDiv) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
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
END_NATIVE()

BEGIN_NATIVE(MintBitNot) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  return process->NewInteger(~x->value());
}
END_NATIVE()

BEGIN_NATIVE(MintBitAnd) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->ToInteger(x->value() & y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintBitOr) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->ToInteger(x->value() | y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintBitXor) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return process->ToInteger(x->value() ^ y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintBitShr) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
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
END_NATIVE()

BEGIN_NATIVE(MintBitShl) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  int64 x_value = x->value();
  int x_bit_length = Utils::BitLength(x_value);
  if (x_bit_length + y_value >= 64) {
    return Failure::index_out_of_bounds();
  }
  return process->ToInteger(x->value() << y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintEqual) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() == y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintLess) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() < y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintLessEqual) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() <= y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintGreater) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() > y_value);
}
END_NATIVE()

BEGIN_NATIVE(MintGreaterEqual) {
  LargeInteger* x = LargeInteger::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsLargeInteger()) return Failure::wrong_argument_type();
  int64 y_value = LargeInteger::cast(y)->value();
  return ToBool(process, x->value() >= y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleNegate) {
  Double* x = Double::cast(arguments[0]);
  return process->NewDouble(-x->value());
}
END_NATIVE()

BEGIN_NATIVE(DoubleAdd) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() + y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleSub) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() - y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleMul) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() * y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleMod) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(fmod(x->value(), y_value));
}
END_NATIVE()

BEGIN_NATIVE(DoubleDiv) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(x->value() / y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleTruncDiv) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  if (y_value == 0) return Failure::index_out_of_bounds();
  return process->NewInteger(static_cast<int64>(x->value() / y_value));
}
END_NATIVE()

BEGIN_NATIVE(DoubleEqual) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() == y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleLess) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() < y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleLessEqual) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() <= y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleGreater) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() > y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleGreaterEqual) {
  Double* x = Double::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double y_value = Double::cast(y)->value();
  return ToBool(process, x->value() >= y_value);
}
END_NATIVE()

BEGIN_NATIVE(DoubleIsNaN) {
  dartino_double d = Double::cast(arguments[0])->value();
  return ToBool(process, isnan(static_cast<double>(d)));
}
END_NATIVE()

BEGIN_NATIVE(DoubleIsNegative) {
  // TODO(ajohnsen): Okay to always use double version?
  double d = static_cast<double>(Double::cast(arguments[0])->value());
  return ToBool(process, (signbit(d) != 0) && !isnan(d));
}
END_NATIVE()

BEGIN_NATIVE(DoubleCeil) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(Double::cast(arguments[0])->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(ceil(value)));
}
END_NATIVE()

BEGIN_NATIVE(DoubleCeilToDouble) {
  Double* x = Double::cast(arguments[0]);
  return process->NewDouble(ceil(x->value()));
}
END_NATIVE()

BEGIN_NATIVE(DoubleRound) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(Double::cast(arguments[0])->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(round(value)));
}
END_NATIVE()

BEGIN_NATIVE(DoubleRoundToDouble) {
  Double* x = Double::cast(arguments[0]);
  return process->NewDouble(round(x->value()));
}
END_NATIVE()

BEGIN_NATIVE(DoubleFloor) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(Double::cast(arguments[0])->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(floor(value)));
}
END_NATIVE()

BEGIN_NATIVE(DoubleFloorToDouble) {
  Double* x = Double::cast(arguments[0]);
  return process->NewDouble(floor(x->value()));
}
END_NATIVE()

BEGIN_NATIVE(DoubleTruncate) {
  // TODO(ajohnsen): Okay to always use double version?
  double value = static_cast<double>(Double::cast(arguments[0])->value());
  if (isnan(value) || isinf(value)) return Failure::index_out_of_bounds();
  return process->ToInteger(static_cast<int64>(trunc(value)));
}
END_NATIVE()

BEGIN_NATIVE(DoubleTruncateToDouble) {
  Double* x = Double::cast(arguments[0]);
  return process->NewDouble(trunc(x->value()));
}
END_NATIVE()

BEGIN_NATIVE(DoubleRemainder) {
  if (!arguments[1]->IsDouble()) return Failure::wrong_argument_type();
  Double* x = Double::cast(arguments[0]);
  Double* y = Double::cast(arguments[1]);
  return process->NewDouble(fmod(x->value(), y->value()));
}
END_NATIVE()

BEGIN_NATIVE(DoubleToInt) {
  // TODO(ajohnsen): Okay to always use double version?
  double d = static_cast<double>(Double::cast(arguments[0])->value());
  if (isinf(d) || isnan(d)) return Failure::index_out_of_bounds();
  // TODO(ager): Handle large doubles that are out of int64 range.
  int64 result = static_cast<int64>(trunc(d));
  return process->ToInteger(result);
}
END_NATIVE()

BEGIN_NATIVE(DoubleToString) {
  static const int kDecimalLow = -6;
  static const int kDecimalHigh = 21;
  static const int kBufferSize = 128;

  Double* d = Double::cast(arguments[0]);
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
END_NATIVE()

BEGIN_NATIVE(DoubleToStringAsExponential) {
  static const int kBufferSize = 128;

  double d = Double::cast(arguments[0])->value();
  int digits = Smi::cast(arguments[1])->value();
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
END_NATIVE()

BEGIN_NATIVE(DoubleToStringAsFixed) {
  static const int kBufferSize = 128;

  double d = Double::cast(arguments[0])->value();
  ASSERT(-1e21 <= d && d <= 1e21);
  int digits = Smi::cast(arguments[1])->value();
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
END_NATIVE()

BEGIN_NATIVE(DoubleToStringAsPrecision) {
  static const int kBufferSize = 128;
  static const int kMaxLeadingPaddingZeroes = 6;
  static const int kMaxTrailingPaddingZeroes = 0;

  double d = Double::cast(arguments[0])->value();
  int digits = Smi::cast(arguments[1])->value();
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
END_NATIVE()

BEGIN_NATIVE(DoubleParse) {
  Object* x = arguments[0];

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
END_NATIVE()

#define DOUBLE_MATH_NATIVE(name, method)                       \
  BEGIN_NATIVE(name) {                                         \
    Object* x = arguments[0];                                  \
    if (!x->IsDouble()) return Failure::wrong_argument_type(); \
    dartino_double d = Double::cast(x)->value();                \
    return process->NewDouble(method(d));                      \
  }                                                            \
  END_NATIVE()

DOUBLE_MATH_NATIVE(DoubleSin, sin)
DOUBLE_MATH_NATIVE(DoubleCos, cos)
DOUBLE_MATH_NATIVE(DoubleTan, tan)
DOUBLE_MATH_NATIVE(DoubleAcos, acos)
DOUBLE_MATH_NATIVE(DoubleAsin, asin)
DOUBLE_MATH_NATIVE(DoubleAtan, atan)
DOUBLE_MATH_NATIVE(DoubleSqrt, sqrt)
DOUBLE_MATH_NATIVE(DoubleExp, exp)
DOUBLE_MATH_NATIVE(DoubleLog, log)

BEGIN_NATIVE(DoubleAtan2) {
  Object* x = arguments[0];
  if (!x->IsDouble()) return Failure::wrong_argument_type();
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double x_value = Double::cast(x)->value();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(atan2(x_value, y_value));
}
END_NATIVE()

BEGIN_NATIVE(DoublePow) {
  Object* x = arguments[0];
  if (!x->IsDouble()) return Failure::wrong_argument_type();
  Object* y = arguments[1];
  if (!y->IsDouble()) return Failure::wrong_argument_type();
  dartino_double x_value = Double::cast(x)->value();
  dartino_double y_value = Double::cast(y)->value();
  return process->NewDouble(pow(x_value, y_value));
}
END_NATIVE()

BEGIN_NATIVE(ListNew) {
  Object* x = arguments[0];
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int length = Smi::cast(arguments[0])->value();
  if (length < 0) return Failure::index_out_of_bounds();
  return process->NewArray(length);
}
END_NATIVE()

BEGIN_NATIVE(ListLength) {
  Object* list = Instance::cast(arguments[0])->GetInstanceField(0);
  return Smi::FromWord(BaseArray::cast(list)->length());
}
END_NATIVE()

BEGIN_NATIVE(ListIndexGet) {
  Object* list = Instance::cast(arguments[0])->GetInstanceField(0);
  Array* array = Array::cast(list);
  Object* x = arguments[1];
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int index = Smi::cast(x)->value();
  if (index < 0 || index >= array->length()) {
    return Failure::index_out_of_bounds();
  }
  return array->get(index);
}
END_NATIVE()

BEGIN_NATIVE(ByteListIndexGet) {
  Object* list = Instance::cast(arguments[0])->GetInstanceField(0);
  ByteArray* array = ByteArray::cast(list);
  Object* x = arguments[1];
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int index = Smi::cast(x)->value();
  if (index < 0 || index >= array->length()) {
    return Failure::index_out_of_bounds();
  }
  return Smi::FromWord(array->get(index));
}
END_NATIVE()

BEGIN_NATIVE(ListIndexSet) {
  Object* list = Instance::cast(arguments[0])->GetInstanceField(0);
  Array* array = Array::cast(list);
  Object* x = arguments[1];
  if (!x->IsSmi()) return Failure::wrong_argument_type();
  int index = Smi::cast(x)->value();
  if (index < 0 || index >= array->length()) {
    return Failure::index_out_of_bounds();
  }
  Object* value = arguments[2];
  array->set(index, value);
  process->RecordStore(array, value);
  return value;
}
END_NATIVE()

BEGIN_NATIVE(ArgumentsLength) {
  return process->ToInteger(process->arguments().length());
}
END_NATIVE()

BEGIN_NATIVE(ArgumentsToString) {
  word index = AsForeignWord(arguments[0]);
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
END_NATIVE()

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

  Process* child = program->SpawnProcess(process);
  if (child == NULL) return NULL;

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
  stack->set(--top, reinterpret_cast<Object*>(InterpreterEntry));
  stack->set(--top, reinterpret_cast<Object*>(frame_pointer));
  stack->set_top(top);

  return child;
}

BEGIN_NATIVE(ProcessSpawn) {
  Program* program = process->program();

  Instance* entrypoint = Instance::cast(arguments[0]);
  Instance* closure = Instance::cast(arguments[1]);
  Object* argument = arguments[2];
  bool link_to_child = arguments[3] == program->true_object();
  bool link_from_child = arguments[4] == program->true_object();
  Object* dart_monitor_port = arguments[5];
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

  if (child == NULL) {
    // TODO(erikcorry): Somehow collect this information instead of trying to
    // remember all allocations here.
    return Failure::retry_after_gc(
        Stack::AllocationSize(Process::kInitialStackSize) + Coroutine::kSize +
        Array::AllocationSize(program->static_fields()->length()));
  }

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
END_NATIVE()

BEGIN_NATIVE(ProcessCurrent) {
  Program* program = process->program();
  ProcessHandle* handle = process->process_handle();

  Object* dart_process = process->NewInstance(program->process_class(), true);
  if (dart_process->IsRetryAfterGCFailure()) return dart_process;
  handle->InitializeDartObject(dart_process);

  return dart_process;
}
END_NATIVE()

BEGIN_NATIVE(CoroutineCurrent) { return process->coroutine(); }
END_NATIVE()

BEGIN_NATIVE(CoroutineNewStack) {
  Object* object = process->NewStack(256);
  if (object->IsFailure()) return object;
  Instance* coroutine = Instance::cast(arguments[0]);
  Instance* entry = Instance::cast(arguments[1]);

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
  stack->set(--top, reinterpret_cast<Object*>(InterpreterCoroutineEntry));
  stack->set(--top, reinterpret_cast<Object*>(frame_pointer));
  stack->set_top(top);
  return stack;
}
END_NATIVE()

BEGIN_NATIVE(StopwatchFrequency) { return Smi::FromWord(1000000); }
END_NATIVE()

BEGIN_NATIVE(StopwatchNow) {
  static uint64 first = 0;
  uint64 now = Platform::GetProcessMicroseconds();
  if (first == 0) first = now;
  return process->ToInteger(now - first);
}
END_NATIVE()

BEGIN_NATIVE(IdentityHashCode) {
  Object* object = arguments[0];
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
END_NATIVE()

char* AsForeignString(Object* object) {
  if (object->IsOneByteString()) {
    return OneByteString::cast(object)->ToCString();
  }
  if (object->IsTwoByteString()) {
    return TwoByteString::cast(object)->ToCString();
  }
  return NULL;
}

BEGIN_NATIVE(StringLength) {
  BaseArray* x = BaseArray::cast(arguments[0]);
  return Smi::FromWord(x->length());
}
END_NATIVE()

BEGIN_NATIVE(OneByteStringAdd) {
  OneByteString* x = OneByteString::cast(arguments[0]);
  Object* other = arguments[1];

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
END_NATIVE()

BEGIN_NATIVE(OneByteStringCodeUnitAt) {
  OneByteString* x = OneByteString::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  if (index >= x->length()) return Failure::index_out_of_bounds();
  return process->ToInteger(x->get_char_code(index));
}
END_NATIVE()

BEGIN_NATIVE(OneByteStringCreate) {
  Object* z = arguments[0];
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word length = Smi::cast(z)->value();
  if (length < 0) return Failure::index_out_of_bounds();
  Object* result = process->NewOneByteString(length);
  return result;
}
END_NATIVE()

BEGIN_NATIVE(OneByteStringEqual) {
  OneByteString* x = OneByteString::cast(arguments[0]);
  Object* y = arguments[1];

  if (y->IsOneByteString()) {
    return ToBool(process, x->Equals(OneByteString::cast(y)));
  }

  if (y->IsTwoByteString()) {
    return ToBool(process, x->Equals(TwoByteString::cast(y)));
  }

  return process->program()->false_object();
}
END_NATIVE()

BEGIN_NATIVE(OneByteStringSetCodeUnitAt) {
  OneByteString* x = OneByteString::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  Object* z = arguments[2];
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word value = Smi::cast(z)->value();
  if (value < 0 || value > 65535) return Failure::wrong_argument_type();
  x->set_char_code(index, value);
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(OneByteStringSetContent) {
  OneByteString* x = OneByteString::cast(arguments[0]);
  Smi* offset = Smi::cast(arguments[1]);
  Object* other = arguments[2];
  if (!other->IsOneByteString()) return Failure::wrong_argument_type();

  OneByteString* y = OneByteString::cast(other);
  x->FillFrom(y, offset->value());
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(OneByteStringSubstring) {
  OneByteString* x = OneByteString::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  Object* z = arguments[2];
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
END_NATIVE()

BEGIN_NATIVE(TwoByteStringLength) {
  TwoByteString* x = TwoByteString::cast(arguments[0]);
  return Smi::FromWord(x->length());
}
END_NATIVE()

BEGIN_NATIVE(TwoByteStringAdd) {
  TwoByteString* x = TwoByteString::cast(arguments[0]);
  Object* other = arguments[1];

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
END_NATIVE()

BEGIN_NATIVE(TwoByteStringCodeUnitAt) {
  TwoByteString* x = TwoByteString::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  if (index >= x->length()) return Failure::index_out_of_bounds();
  return process->ToInteger(x->get_code_unit(index));
}
END_NATIVE()

BEGIN_NATIVE(TwoByteStringCreate) {
  Object* z = arguments[0];
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word length = Smi::cast(z)->value();
  if (length < 0) return Failure::index_out_of_bounds();
  Object* result = process->NewTwoByteString(length);
  return result;
}
END_NATIVE()

BEGIN_NATIVE(TwoByteStringEqual) {
  TwoByteString* x = TwoByteString::cast(arguments[0]);
  Object* y = arguments[1];

  if (y->IsOneByteString()) {
    return ToBool(process, OneByteString::cast(y)->Equals(x));
  }

  if (y->IsTwoByteString()) {
    return ToBool(process, x->Equals(TwoByteString::cast(y)));
  }

  return process->program()->false_object();
}
END_NATIVE()

BEGIN_NATIVE(TwoByteStringSetCodeUnitAt) {
  TwoByteString* x = TwoByteString::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  word index = Smi::cast(y)->value();
  if (index < 0) return Failure::index_out_of_bounds();
  Object* z = arguments[2];
  if (!z->IsSmi()) return Failure::wrong_argument_type();
  word value = Smi::cast(z)->value();
  if (value < 0 || value > 65535) return Failure::wrong_argument_type();
  x->set_code_unit(index, value);
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(TwoByteStringSetContent) {
  TwoByteString* x = TwoByteString::cast(arguments[0]);
  Smi* offset = Smi::cast(arguments[1]);
  Object* other = arguments[2];

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
END_NATIVE()

BEGIN_NATIVE(TwoByteStringSubstring) {
  TwoByteString* x = TwoByteString::cast(arguments[0]);
  Object* y = arguments[1];
  if (!y->IsSmi()) return Failure::wrong_argument_type();
  Object* z = arguments[2];
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
END_NATIVE()

BEGIN_NATIVE(DateTimeGetCurrentMs) {
  uint64 us = Platform::GetMicroseconds();
  return process->ToInteger(us / 1000);
}
END_NATIVE()

static int64 kMaxTimeZoneOffsetSeconds = 2100000000;

BEGIN_NATIVE(DateTimeTimeZone) {
  word seconds = AsForeignWord(arguments[0]);
  if (seconds < 0 || seconds > kMaxTimeZoneOffsetSeconds) {
    return Failure::index_out_of_bounds();
  }
  const char* name = Platform::GetTimeZoneName(seconds);
  return process->NewStringFromAscii(List<const char>(name, strlen(name)));
}
END_NATIVE()

BEGIN_NATIVE(DateTimeTimeZoneOffset) {
  word seconds = AsForeignWord(arguments[0]);
  if (seconds < 0 || seconds > kMaxTimeZoneOffsetSeconds) {
    return Failure::index_out_of_bounds();
  }
  int offset = Platform::GetTimeZoneOffset(seconds);
  return process->ToInteger(offset);
}
END_NATIVE()

BEGIN_NATIVE(DateTimeLocalTimeZoneOffset) {
  int offset = Platform::GetLocalTimeZoneOffset();
  return process->ToInteger(offset);
}
END_NATIVE()

BEGIN_NATIVE(SystemEventHandlerAdd) {
  Object* id = arguments[0];
  Object* port_arg = arguments[1];
  if (!port_arg->IsPort()) {
    return Failure::wrong_argument_type();
  }
  Port* port = Port::FromDartObject(port_arg);
  Object* flags_arg = arguments[2];
  if (!flags_arg->IsSmi()) return Failure::wrong_argument_type();
  int flags = Smi::cast(flags_arg)->value();
  return EventHandler::GlobalInstance()->Add(process, id, port, flags);
}
END_NATIVE()

BEGIN_NATIVE(IsImmutable) {
  Object* o = arguments[0];
  return ToBool(process, o->IsImmutable());
}
END_NATIVE()

BEGIN_NATIVE(Uint32DigitsAllocate) {
  Smi* length = Smi::cast(arguments[0]);
  word byte_size = length->value() * 4;
  return process->NewByteArray(byte_size);
}
END_NATIVE()

BEGIN_NATIVE(Uint32DigitsGet) {
  ByteArray* backing = ByteArray::cast(arguments[0]);
  Smi* index = Smi::cast(arguments[1]);
  word byte_index = index->value() * 4;
  ASSERT(byte_index + 4 <= backing->length());
  uint8* byte_address = backing->byte_address_for(byte_index);
  return process->ToInteger(*reinterpret_cast<uint32*>(byte_address));
}
END_NATIVE()

BEGIN_NATIVE(Uint32DigitsSet) {
  ByteArray* backing = ByteArray::cast(arguments[0]);
  Smi* index = Smi::cast(arguments[1]);
  word byte_index = index->value() * 4;
  ASSERT(byte_index + 4 <= backing->length());
  uint8* byte_address = backing->byte_address_for(byte_index);
  Object* object = arguments[2];
  uint32 value = object->IsSmi() ? Smi::cast(object)->value()
                                 : LargeInteger::cast(object)->value();
  *reinterpret_cast<uint32*>(byte_address) = value;
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(TimerScheduleTimeout) {
  int64 timeout = AsForeignInt64(arguments[0]);
  Port* port = Port::FromDartObject(arguments[1]);
  EventHandler::GlobalInstance()->ScheduleTimeout(timeout, port);
  return process->program()->null_object();
}
END_NATIVE()

BEGIN_NATIVE(EventHandlerSleep) {
  int64 arg = AsForeignInt64(arguments[0]);
  // Adding one (1) if the sleep is not for 0 ms. This ensures that the
  // sleep will last at least the provided number of milliseconds.
  int64 offset = arg == 0 ? 0 : 1;
  int64 timeout = arg + Platform::GetMicroseconds() / 1000 + offset;
  Port* port = Port::FromDartObject(arguments[1]);
  EventHandler::GlobalInstance()->ScheduleTimeout(timeout, port);
  return process->program()->null_object();
}
END_NATIVE()

}  // namespace dartino
