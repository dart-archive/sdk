// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_NATIVES_H_
#define SRC_SHARED_NATIVES_H_

namespace dartino {

#define NATIVES_DO(N)                                                        \
  N(PrintToConsole, "<none>", "printToConsole", false)                       \
  N(ExposeGC, "<none>", "_exposeGC", false)                                  \
  N(GC, "<none>", "_gc", false)                                              \
                                                                             \
  N(IntParse, "int", "_parse", false)                                        \
                                                                             \
  N(SmiToDouble, "_Smi", "toDouble", false)                                  \
  N(SmiToString, "_Smi", "toString", false)                                  \
  N(SmiToMint, "_Smi", "_toMint", false)                                     \
                                                                             \
  N(SmiNegate, "_Smi", "unary-", false)                                      \
                                                                             \
  N(SmiAdd, "_Smi", "+", false)                                              \
  N(SmiSub, "_Smi", "-", false)                                              \
  N(SmiMul, "_Smi", "*", false)                                              \
  N(SmiMod, "_Smi", "%", false)                                              \
  N(SmiDiv, "_Smi", "/", false)                                              \
  N(SmiTruncDiv, "_Smi", "~/", false)                                        \
                                                                             \
  N(SmiBitNot, "_Smi", "~", false)                                           \
  N(SmiBitAnd, "_Smi", "&", false)                                           \
  N(SmiBitOr, "_Smi", "|", false)                                            \
  N(SmiBitXor, "_Smi", "^", false)                                           \
  N(SmiBitShr, "_Smi", ">>", false)                                          \
  N(SmiBitShl, "_Smi", "<<", false)                                          \
                                                                             \
  N(SmiEqual, "_Smi", "==", false)                                           \
  N(SmiLess, "_Smi", "<", false)                                             \
  N(SmiLessEqual, "_Smi", "<=", false)                                       \
  N(SmiGreater, "_Smi", ">", false)                                          \
  N(SmiGreaterEqual, "_Smi", ">=", false)                                    \
                                                                             \
  N(MintToDouble, "_Mint", "toDouble", false)                                \
  N(MintToString, "_Mint", "toString", false)                                \
                                                                             \
  N(MintNegate, "_Mint", "unary-", false)                                    \
                                                                             \
  N(MintAdd, "_Mint", "+", false)                                            \
  N(MintSub, "_Mint", "-", false)                                            \
  N(MintMul, "_Mint", "*", false)                                            \
  N(MintMod, "_Mint", "%", false)                                            \
  N(MintDiv, "_Mint", "/", false)                                            \
  N(MintTruncDiv, "_Mint", "~/", false)                                      \
                                                                             \
  N(MintBitNot, "_Mint", "~", false)                                         \
  N(MintBitAnd, "_Mint", "&", false)                                         \
  N(MintBitOr, "_Mint", "|", false)                                          \
  N(MintBitXor, "_Mint", "^", false)                                         \
  N(MintBitShr, "_Mint", ">>", false)                                        \
  N(MintBitShl, "_Mint", "<<", false)                                        \
                                                                             \
  N(MintEqual, "_Mint", "==", false)                                         \
  N(MintLess, "_Mint", "<", false)                                           \
  N(MintLessEqual, "_Mint", "<=", false)                                     \
  N(MintGreater, "_Mint", ">", false)                                        \
  N(MintGreaterEqual, "_Mint", ">=", false)                                  \
                                                                             \
  N(DoubleNegate, "_DoubleImpl", "unary-", false)                            \
                                                                             \
  N(DoubleAdd, "_DoubleImpl", "+", false)                                    \
  N(DoubleSub, "_DoubleImpl", "-", false)                                    \
  N(DoubleMul, "_DoubleImpl", "*", false)                                    \
  N(DoubleMod, "_DoubleImpl", "%", false)                                    \
  N(DoubleDiv, "_DoubleImpl", "/", false)                                    \
  N(DoubleTruncDiv, "_DoubleImpl", "~/", false)                              \
                                                                             \
  N(DoubleEqual, "_DoubleImpl", "==", false)                                 \
  N(DoubleLess, "_DoubleImpl", "<", false)                                   \
  N(DoubleLessEqual, "_DoubleImpl", "<=", false)                             \
  N(DoubleGreater, "_DoubleImpl", ">", false)                                \
  N(DoubleGreaterEqual, "_DoubleImpl", ">=", false)                          \
                                                                             \
  N(DoubleIsNaN, "_DoubleImpl", "isNaN", false)                              \
  N(DoubleIsNegative, "_DoubleImpl", "isNegative", false)                    \
                                                                             \
  N(DoubleCeil, "_DoubleImpl", "ceil", false)                                \
  N(DoubleCeilToDouble, "_DoubleImpl", "ceilToDouble", false)                \
  N(DoubleRound, "_DoubleImpl", "round", false)                              \
  N(DoubleRoundToDouble, "_DoubleImpl", "roundToDouble", false)              \
  N(DoubleFloor, "_DoubleImpl", "floor", false)                              \
  N(DoubleFloorToDouble, "_DoubleImpl", "floorToDouble", false)              \
  N(DoubleTruncate, "_DoubleImpl", "truncate", false)                        \
  N(DoubleTruncateToDouble, "_DoubleImpl", "truncateToDouble", false)        \
  N(DoubleRemainder, "_DoubleImpl", "remainder", false)                      \
  N(DoubleToInt, "_DoubleImpl", "toInt", false)                              \
  N(DoubleToString, "_DoubleImpl", "toString", false)                        \
  N(DoubleToStringAsExponential, "_DoubleImpl", "_toStringAsExponential",    \
    false)                                                                   \
  N(DoubleToStringAsFixed, "_DoubleImpl", "_toStringAsFixed", false)         \
  N(DoubleToStringAsPrecision, "_DoubleImpl", "_toStringAsPrecision", false) \
                                                                             \
  N(DoubleParse, "double", "_parse", false)                                  \
                                                                             \
  N(DoubleSin, "<none>", "_sin", false)                                      \
  N(DoubleCos, "<none>", "_cos", false)                                      \
  N(DoubleTan, "<none>", "_tan", false)                                      \
  N(DoubleAcos, "<none>", "_acos", false)                                    \
  N(DoubleAsin, "<none>", "_asin", false)                                    \
  N(DoubleAtan, "<none>", "_atan", false)                                    \
  N(DoubleSqrt, "<none>", "_sqrt", false)                                    \
  N(DoubleExp, "<none>", "_exp", false)                                      \
  N(DoubleLog, "<none>", "_log", false)                                      \
  N(DoubleAtan2, "<none>", "_atan2", false)                                  \
  N(DoublePow, "<none>", "_pow", false)                                      \
                                                                             \
  N(DateTimeGetCurrentMs, "DateTime", "_getCurrentMs", false)                \
  N(DateTimeTimeZone, "DateTime", "_timeZone", false)                        \
  N(DateTimeTimeZoneOffset, "DateTime", "_timeZoneOffset", false)            \
  N(DateTimeLocalTimeZoneOffset, "DateTime", "_localTimeZoneOffset", false)  \
                                                                             \
  N(ListNew, "_FixedListBase", "_new", false)                                \
  N(ListLength, "_FixedListBase", "length", false)                           \
  N(ListIndexGet, "_FixedListBase", "[]", false)                             \
                                                                             \
  N(ByteListIndexGet, "_ConstantByteList", "[]", false)                      \
                                                                             \
  N(ListIndexSet, "_FixedList", "[]=", false)                                \
                                                                             \
  N(ArgumentsLength, "_Arguments", "length", false)                          \
  N(ArgumentsToString, "_Arguments", "_toString", false)                     \
                                                                             \
  N(ProcessSpawn, "Process", "_spawn", false)                                \
  N(ProcessQueueGetMessage, "Process", "_queueGetMessage", false)            \
  N(ProcessQueueSetupProcessDeath, "Process", "_queueSetupProcessDeath",     \
    false)                                                                   \
  N(ProcessQueueGetChannel, "Process", "_queueGetChannel", false)            \
  N(ProcessCurrent, "Process", "current", false)                             \
                                                                             \
  N(CoroutineCurrent, "Coroutine", "_coroutineCurrent", false)               \
  N(CoroutineNewStack, "Coroutine", "_coroutineNewStack", false)             \
                                                                             \
  N(StopwatchFrequency, "Stopwatch", "_frequency", false)                    \
  N(StopwatchNow, "Stopwatch", "_now", false)                                \
                                                                             \
  N(TimerScheduleTimeout, "_DartinoTimer", "_scheduleTimeout", false)        \
  N(EventHandlerSleep, "<none>", "_sleep", false)                            \
                                                                             \
  N(ForeignLibraryLookup, "ForeignLibrary", "_lookupLibrary", false)         \
  N(ForeignLibraryGetFunction, "ForeignLibrary", "_lookupFunction", false)   \
  N(ForeignLibraryBundlePath, "ForeignLibrary", "bundleLibraryName", false)  \
                                                                             \
  N(ForeignBitsPerWord, "Foreign", "_bitsPerMachineWord", false)             \
  N(ForeignErrno, "Foreign", "_errno", false)                                \
  N(ForeignPlatform, "Foreign", "_platform", false)                          \
  N(ForeignArchitecture, "Foreign", "_architecture", false)                  \
  N(ForeignConvertPort, "Foreign", "_convertPort", false)                    \
                                                                             \
  N(ForeignICall0, "ForeignFunction", "_icall$0", true)                      \
  N(ForeignICall1, "ForeignFunction", "_icall$1", true)                      \
  N(ForeignICall2, "ForeignFunction", "_icall$2", true)                      \
  N(ForeignICall3, "ForeignFunction", "_icall$3", true)                      \
  N(ForeignICall4, "ForeignFunction", "_icall$4", true)                      \
  N(ForeignICall5, "ForeignFunction", "_icall$5", true)                      \
  N(ForeignICall6, "ForeignFunction", "_icall$6", true)                      \
  N(ForeignICall7, "ForeignFunction", "_icall$7", true)                      \
                                                                             \
  N(ForeignPCall0, "ForeignFunction", "_pcall$0", true)                      \
  N(ForeignPCall1, "ForeignFunction", "_pcall$1", true)                      \
  N(ForeignPCall2, "ForeignFunction", "_pcall$2", true)                      \
  N(ForeignPCall3, "ForeignFunction", "_pcall$3", true)                      \
  N(ForeignPCall4, "ForeignFunction", "_pcall$4", true)                      \
  N(ForeignPCall5, "ForeignFunction", "_pcall$5", true)                      \
  N(ForeignPCall6, "ForeignFunction", "_pcall$6", true)                      \
                                                                             \
  N(ForeignVCall0, "ForeignFunction", "_vcall$0", true)                      \
  N(ForeignVCall1, "ForeignFunction", "_vcall$1", true)                      \
  N(ForeignVCall2, "ForeignFunction", "_vcall$2", true)                      \
  N(ForeignVCall3, "ForeignFunction", "_vcall$3", true)                      \
  N(ForeignVCall4, "ForeignFunction", "_vcall$4", true)                      \
  N(ForeignVCall5, "ForeignFunction", "_vcall$5", true)                      \
  N(ForeignVCall6, "ForeignFunction", "_vcall$6", true)                      \
                                                                             \
  N(ForeignLCallwLw, "ForeignFunction", "_Lcall$wLw", true)                  \
                                                                             \
  N(ForeignRegisterFinalizer, "Foreign", "_registerFinalizer", false)        \
  N(ForeignRemoveFinalizer, "Foreign", "_removeFinalizer", false)            \
                                                                             \
  N(ForeignDecreaseMemoryUsage, "ForeignMemory", "_decreaseMemoryUsage",     \
    false)                                                                   \
  N(ForeignMarkForFinalization, "UnsafeMemory", "_markForFinalization",      \
    false)                                                                   \
  N(ForeignAllocate, "UnsafeMemory", "_allocate", false)                     \
                                                                             \
  N(ForeignGetInt8, "UnsafeMemory", "_getInt8", false)                       \
  N(ForeignGetInt16, "UnsafeMemory", "_getInt16", false)                     \
  N(ForeignGetInt32, "UnsafeMemory", "_getInt32", false)                     \
  N(ForeignGetInt64, "UnsafeMemory", "_getInt64", false)                     \
                                                                             \
  N(ForeignSetInt8, "UnsafeMemory", "_setInt8", false)                       \
  N(ForeignSetInt16, "UnsafeMemory", "_setInt16", false)                     \
  N(ForeignSetInt32, "UnsafeMemory", "_setInt32", false)                     \
  N(ForeignSetInt64, "UnsafeMemory", "_setInt64", false)                     \
                                                                             \
  N(ForeignGetUint8, "UnsafeMemory", "_getUint8", false)                     \
  N(ForeignGetUint16, "UnsafeMemory", "_getUint16", false)                   \
  N(ForeignGetUint32, "UnsafeMemory", "_getUint32", false)                   \
  N(ForeignGetUint64, "UnsafeMemory", "_getUint64", false)                   \
                                                                             \
  N(ForeignSetUint8, "UnsafeMemory", "_setUint8", false)                     \
  N(ForeignSetUint16, "UnsafeMemory", "_setUint16", false)                   \
  N(ForeignSetUint32, "UnsafeMemory", "_setUint32", false)                   \
  N(ForeignSetUint64, "UnsafeMemory", "_setUint64", false)                   \
                                                                             \
  N(ForeignGetFloat32, "UnsafeMemory", "_getFloat32", false)                 \
  N(ForeignGetFloat64, "UnsafeMemory", "_getFloat64", false)                 \
                                                                             \
  N(ForeignSetFloat32, "UnsafeMemory", "_setFloat32", false)                 \
  N(ForeignSetFloat64, "UnsafeMemory", "_setFloat64", false)                 \
                                                                             \
  N(ForeignFree, "ForeignMemory", "_free", false)                            \
                                                                             \
  N(StringLength, "_StringBase", "length", false)                            \
                                                                             \
  N(OneByteStringAdd, "_OneByteString", "+", false)                          \
  N(OneByteStringCodeUnitAt, "_OneByteString", "codeUnitAt", false)          \
  N(OneByteStringCreate, "_OneByteString", "_create", false)                 \
  N(OneByteStringEqual, "_OneByteString", "==", false)                       \
  N(OneByteStringSetCodeUnitAt, "_OneByteString", "_setCodeUnitAt", false)   \
  N(OneByteStringSetContent, "_OneByteString", "_setContent", false)         \
  N(OneByteStringSubstring, "_OneByteString", "_substring", false)           \
                                                                             \
  N(TwoByteStringAdd, "_TwoByteString", "+", false)                          \
  N(TwoByteStringCodeUnitAt, "_TwoByteString", "codeUnitAt", false)          \
  N(TwoByteStringCreate, "_TwoByteString", "_create", false)                 \
  N(TwoByteStringEqual, "_TwoByteString", "==", false)                       \
  N(TwoByteStringSetCodeUnitAt, "_TwoByteString", "_setCodeUnitAt", false)   \
  N(TwoByteStringSetContent, "_TwoByteString", "_setContent", false)         \
  N(TwoByteStringSubstring, "_TwoByteString", "_substring", false)           \
                                                                             \
  N(UriBase, "Uri", "_base", false)                                          \
                                                                             \
  N(ProcessLink, "Process", "link", false)                                   \
  N(ProcessUnlink, "Process", "unlink", false)                               \
  N(ProcessMonitor, "Process", "monitor", false)                             \
  N(ProcessUnmonitor, "Process", "unmonitor", false)                         \
  N(ProcessKill, "Process", "kill", false)                                   \
                                                                             \
  N(PortCreate, "Port", "_create", false)                                    \
  N(PortSend, "Port", "send", false)                                         \
  N(PortSendExit, "Port", "_sendExit", false)                                \
                                                                             \
  N(SystemEventHandlerAdd, "EventHandler", "_eventHandlerAdd", false)        \
                                                                             \
  N(ServiceRegister, "<none>", "register", false)                            \
                                                                             \
  N(IsImmutable, "<none>", "_isImmutable", false)                            \
  N(IdentityHashCode, "<none>", "_identityHashCode", false)                  \
                                                                             \
  N(NativeProcessSpawnDetached, "NativeProcess", "_spawnDetached", false)    \
                                                                             \
  N(Uint32DigitsAllocate, "_Uint32Digits", "_allocate", false)               \
  N(Uint32DigitsGet, "_Uint32Digits", "_getUint32", false)                   \
  N(Uint32DigitsSet, "_Uint32Digits", "_setUint32", false)

enum Native {
#define N(e, c, n, d) k##e,
  NATIVES_DO(N)
#undef N
      kNumberOfNatives
};

#define N(e, c, n, d) const bool kIsDetachable_##e = d;
NATIVES_DO(N)
#undef N


}  // namespace dartino

#endif  // SRC_SHARED_NATIVES_H_
