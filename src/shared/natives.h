// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_NATIVES_H_
#define SRC_SHARED_NATIVES_H_

namespace dartino {

#define NATIVES_DO(N)                                                          \
  N(PrintToConsole, "<none>", "printToConsole", true)                          \
  N(ExposeGC, "<none>", "_exposeGC", true)                                     \
  N(GC, "<none>", "_gc", true)                                                 \
                                                                               \
  N(IntParse, "int", "_parse", true)                                           \
                                                                               \
  N(SmiToDouble, "_Smi", "toDouble", true)                                     \
  N(SmiToString, "_Smi", "toString", true)                                     \
  N(SmiToMint, "_Smi", "_toMint", true)                                        \
                                                                               \
  N(SmiNegate, "_Smi", "unary-", true)                                         \
                                                                               \
  N(SmiAdd, "_Smi", "+", true)                                                 \
  N(SmiSub, "_Smi", "-", true)                                                 \
  N(SmiMul, "_Smi", "*", true)                                                 \
  N(SmiMod, "_Smi", "%", true)                                                 \
  N(SmiDiv, "_Smi", "/", true)                                                 \
  N(SmiTruncDiv, "_Smi", "~/", true)                                           \
                                                                               \
  N(SmiBitNot, "_Smi", "~", true)                                              \
  N(SmiBitAnd, "_Smi", "&", true)                                              \
  N(SmiBitOr, "_Smi", "|", true)                                               \
  N(SmiBitXor, "_Smi", "^", true)                                              \
  N(SmiBitShr, "_Smi", ">>", true)                                             \
  N(SmiBitShl, "_Smi", "<<", true)                                             \
                                                                               \
  N(SmiEqual, "_Smi", "==", true)                                              \
  N(SmiLess, "_Smi", "<", true)                                                \
  N(SmiLessEqual, "_Smi", "<=", true)                                          \
  N(SmiGreater, "_Smi", ">", true)                                             \
  N(SmiGreaterEqual, "_Smi", ">=", true)                                       \
                                                                               \
  N(MintToDouble, "_Mint", "toDouble", true)                                   \
  N(MintToString, "_Mint", "toString", true)                                   \
                                                                               \
  N(MintNegate, "_Mint", "unary-", true)                                       \
                                                                               \
  N(MintAdd, "_Mint", "+", true)                                               \
  N(MintSub, "_Mint", "-", true)                                               \
  N(MintMul, "_Mint", "*", true)                                               \
  N(MintMod, "_Mint", "%", true)                                               \
  N(MintDiv, "_Mint", "/", true)                                               \
  N(MintTruncDiv, "_Mint", "~/", true)                                         \
                                                                               \
  N(MintBitNot, "_Mint", "~", true)                                            \
  N(MintBitAnd, "_Mint", "&", true)                                            \
  N(MintBitOr, "_Mint", "|", true)                                             \
  N(MintBitXor, "_Mint", "^", true)                                            \
  N(MintBitShr, "_Mint", ">>", true)                                           \
  N(MintBitShl, "_Mint", "<<", true)                                           \
                                                                               \
  N(MintEqual, "_Mint", "==", true)                                            \
  N(MintLess, "_Mint", "<", true)                                              \
  N(MintLessEqual, "_Mint", "<=", true)                                        \
  N(MintGreater, "_Mint", ">", true)                                           \
  N(MintGreaterEqual, "_Mint", ">=", true)                                     \
                                                                               \
  N(DoubleNegate, "_DoubleImpl", "unary-", true)                               \
                                                                               \
  N(DoubleAdd, "_DoubleImpl", "+", true)                                       \
  N(DoubleSub, "_DoubleImpl", "-", true)                                       \
  N(DoubleMul, "_DoubleImpl", "*", true)                                       \
  N(DoubleMod, "_DoubleImpl", "%", true)                                       \
  N(DoubleDiv, "_DoubleImpl", "/", true)                                       \
  N(DoubleTruncDiv, "_DoubleImpl", "~/", true)                                 \
                                                                               \
  N(DoubleEqual, "_DoubleImpl", "==", true)                                    \
  N(DoubleLess, "_DoubleImpl", "<", true)                                      \
  N(DoubleLessEqual, "_DoubleImpl", "<=", true)                                \
  N(DoubleGreater, "_DoubleImpl", ">", true)                                   \
  N(DoubleGreaterEqual, "_DoubleImpl", ">=", true)                             \
                                                                               \
  N(DoubleIsNaN, "_DoubleImpl", "isNaN", true)                                 \
  N(DoubleIsNegative, "_DoubleImpl", "isNegative", true)                       \
                                                                               \
  N(DoubleCeil, "_DoubleImpl", "ceil", true)                                   \
  N(DoubleCeilToDouble, "_DoubleImpl", "ceilToDouble", true)                   \
  N(DoubleRound, "_DoubleImpl", "round", true)                                 \
  N(DoubleRoundToDouble, "_DoubleImpl", "roundToDouble", true)                 \
  N(DoubleFloor, "_DoubleImpl", "floor", true)                                 \
  N(DoubleFloorToDouble, "_DoubleImpl", "floorToDouble", true)                 \
  N(DoubleTruncate, "_DoubleImpl", "truncate", true)                           \
  N(DoubleTruncateToDouble, "_DoubleImpl", "truncateToDouble", true)           \
  N(DoubleRemainder, "_DoubleImpl", "remainder", true)                         \
  N(DoubleToInt, "_DoubleImpl", "toInt", true)                                 \
  N(DoubleToString, "_DoubleImpl", "toString", true)                           \
  N(DoubleToStringAsExponential, "_DoubleImpl", "_toStringAsExponential",      \
    false)                                                                     \
  N(DoubleToStringAsFixed, "_DoubleImpl", "_toStringAsFixed", true)            \
  N(DoubleToStringAsPrecision, "_DoubleImpl", "_toStringAsPrecision", true)    \
                                                                               \
  N(DoubleParse, "double", "_parse", true)                                     \
                                                                               \
  N(DoubleSin, "<none>", "_sin", true)                                         \
  N(DoubleCos, "<none>", "_cos", true)                                         \
  N(DoubleTan, "<none>", "_tan", true)                                         \
  N(DoubleAcos, "<none>", "_acos", true)                                       \
  N(DoubleAsin, "<none>", "_asin", true)                                       \
  N(DoubleAtan, "<none>", "_atan", true)                                       \
  N(DoubleSqrt, "<none>", "_sqrt", true)                                       \
  N(DoubleExp, "<none>", "_exp", true)                                         \
  N(DoubleLog, "<none>", "_log", true)                                         \
  N(DoubleAtan2, "<none>", "_atan2", true)                                     \
  N(DoublePow, "<none>", "_pow", true)                                         \
                                                                               \
  N(DateTimeGetCurrentMicros, "DateTime", "_getCurrentMicros", true)           \
  N(DateTimeTimeZone, "DateTime", "_timeZone", true)                           \
  N(DateTimeTimeZoneOffset, "DateTime", "_timeZoneOffset", true)               \
  N(DateTimeLocalTimeZoneOffset, "DateTime", "_localTimeZoneOffset", true)     \
                                                                               \
  N(ListNew, "FixedListBase", "_new", true)                                    \
  N(ListLength, "FixedListBase", "length", true)                               \
  N(ListIndexGet, "FixedListBase", "[]", true)                                 \
                                                                               \
  N(ByteListIndexGet, "_ConstantByteList", "[]", true)                         \
                                                                               \
  N(ListIndexSet, "FixedList", "[]=", true)                                    \
                                                                               \
  N(ArgumentsLength, "_Arguments", "length", true)                             \
  N(ArgumentsToString, "_Arguments", "_toString", true)                        \
                                                                               \
  N(ProcessSpawn, "Process", "_spawn", true)                                   \
  N(ProcessQueueGetMessage, "Process", "_queueGetMessage", true)               \
  N(ProcessQueueSetupProcessDeath, "Process", "_queueSetupProcessDeath",       \
    false)                                                                     \
  N(ProcessQueueGetChannel, "Process", "_queueGetChannel", true)               \
  N(ProcessCurrent, "Process", "current", true)                                \
                                                                               \
  N(CoroutineCurrent, "Coroutine", "_coroutineCurrent", true)                  \
  N(CoroutineNewStack, "Coroutine", "_coroutineNewStack", true)                \
                                                                               \
  N(StopwatchFrequency, "Stopwatch", "_frequency", true)                       \
  N(StopwatchNow, "Stopwatch", "_now", true)                                   \
                                                                               \
  N(TimerScheduleTimeout, "_DartinoTimer", "_scheduleTimeout", true)           \
  N(EventHandlerSleep, "<none>", "_sleep", true)                               \
                                                                               \
  N(ForeignLibraryLookup, "ForeignLibrary", "_lookupLibrary", true)            \
  N(ForeignLibraryGetFunction, "ForeignLibrary", "_lookupFunction", true)      \
  N(ForeignLibraryBundlePath, "ForeignLibrary", "bundleLibraryName", true)     \
                                                                               \
  N(ForeignBitsPerWord, "Foreign", "_bitsPerMachineWord", true)                \
  N(ForeignBitsPerDouble, "Foreign", "_bitsPerDouble", true)                   \
  N(ForeignErrno, "Foreign", "_errno", true)                                   \
  N(ForeignPlatform, "Foreign", "_platform", true)                             \
  N(ForeignArchitecture, "Foreign", "_architecture", true)                     \
  N(ForeignConvertPort, "ForeignConversion", "convertPort", true)              \
                                                                               \
  N(ForeignDoubleToSignedBits, "ForeignFunction", "doubleToSignedBits", true) \
  N(ForeignSignedBitsToDouble, "ForeignFunction", "signedBitsToDouble", true) \
  N(ForeignICall0, "ForeignFunction", "_icall$0", false)                       \
  N(ForeignICall1, "ForeignFunction", "_icall$1", false)                       \
  N(ForeignICall2, "ForeignFunction", "_icall$2", false)                       \
  N(ForeignICall3, "ForeignFunction", "_icall$3", false)                       \
  N(ForeignICall4, "ForeignFunction", "_icall$4", false)                       \
  N(ForeignICall5, "ForeignFunction", "_icall$5", false)                       \
  N(ForeignICall6, "ForeignFunction", "_icall$6", false)                       \
  N(ForeignICall7, "ForeignFunction", "_icall$7", false)                       \
                                                                               \
  N(ForeignPCall0, "ForeignFunction", "_pcall$0", false)                       \
  N(ForeignPCall1, "ForeignFunction", "_pcall$1", false)                       \
  N(ForeignPCall2, "ForeignFunction", "_pcall$2", false)                       \
  N(ForeignPCall3, "ForeignFunction", "_pcall$3", false)                       \
  N(ForeignPCall4, "ForeignFunction", "_pcall$4", false)                       \
  N(ForeignPCall5, "ForeignFunction", "_pcall$5", false)                       \
  N(ForeignPCall6, "ForeignFunction", "_pcall$6", false)                       \
                                                                               \
  N(ForeignVCall0, "ForeignFunction", "_vcall$0", false)                       \
  N(ForeignVCall1, "ForeignFunction", "_vcall$1", false)                       \
  N(ForeignVCall2, "ForeignFunction", "_vcall$2", false)                       \
  N(ForeignVCall3, "ForeignFunction", "_vcall$3", false)                       \
  N(ForeignVCall4, "ForeignFunction", "_vcall$4", false)                       \
  N(ForeignVCall5, "ForeignFunction", "_vcall$5", false)                       \
  N(ForeignVCall6, "ForeignFunction", "_vcall$6", false)                       \
  N(ForeignVCall7, "ForeignFunction", "_vcall$7", false)                       \
                                                                               \
  N(ForeignLCallwLw, "ForeignFunction", "_Lcall$wLw", false)                   \
                                                                               \
  N(ForeignRegisterFinalizer, "Foreign", "_registerFinalizer", true)           \
  N(ForeignRemoveFinalizer, "Foreign", "_removeFinalizer", true)               \
                                                                               \
  N(AllocateFunctionPointer, "ForeignCallback", "_allocateFunctionPointer",    \
    true)                                                                      \
  N(FreeFunctionPointer, "ForeignCallback", "_freeFunctionPointer", true)      \
                                                                               \
  N(ForeignDecreaseMemoryUsage, "ForeignMemory", "_decreaseMemoryUsage",       \
    false)                                                                     \
  N(ForeignMarkForFinalization, "UnsafeMemory", "_markForFinalization", false) \
  N(ForeignAllocate, "UnsafeMemory", "_allocate", true)                        \
                                                                               \
  N(ForeignGetInt8, "UnsafeMemory", "_getInt8", true)                          \
  N(ForeignGetInt16, "UnsafeMemory", "_getInt16", true)                        \
  N(ForeignGetInt32, "UnsafeMemory", "_getInt32", true)                        \
  N(ForeignGetInt64, "UnsafeMemory", "_getInt64", true)                        \
                                                                               \
  N(ForeignSetInt8, "UnsafeMemory", "_setInt8", true)                          \
  N(ForeignSetInt16, "UnsafeMemory", "_setInt16", true)                        \
  N(ForeignSetInt32, "UnsafeMemory", "_setInt32", true)                        \
  N(ForeignSetInt64, "UnsafeMemory", "_setInt64", true)                        \
                                                                               \
  N(ForeignGetUint8, "UnsafeMemory", "_getUint8", true)                        \
  N(ForeignGetUint16, "UnsafeMemory", "_getUint16", true)                      \
  N(ForeignGetUint32, "UnsafeMemory", "_getUint32", true)                      \
  N(ForeignGetUint64, "UnsafeMemory", "_getUint64", true)                      \
                                                                               \
  N(ForeignSetUint8, "UnsafeMemory", "_setUint8", true)                        \
  N(ForeignSetUint16, "UnsafeMemory", "_setUint16", true)                      \
  N(ForeignSetUint32, "UnsafeMemory", "_setUint32", true)                      \
  N(ForeignSetUint64, "UnsafeMemory", "_setUint64", true)                      \
                                                                               \
  N(ForeignGetFloat32, "UnsafeMemory", "_getFloat32", true)                    \
  N(ForeignGetFloat64, "UnsafeMemory", "_getFloat64", true)                    \
                                                                               \
  N(ForeignSetFloat32, "UnsafeMemory", "_setFloat32", true)                    \
  N(ForeignSetFloat64, "UnsafeMemory", "_setFloat64", true)                    \
                                                                               \
  N(ForeignFree, "ForeignMemory", "_free", true)                               \
                                                                               \
  N(StringLength, "_StringBase", "length", true)                               \
                                                                               \
  N(OneByteStringAdd, "_OneByteString", "+", true)                             \
  N(OneByteStringCodeUnitAt, "_OneByteString", "codeUnitAt", true)             \
  N(OneByteStringCreate, "_OneByteString", "_create", true)                    \
  N(OneByteStringEqual, "_OneByteString", "==", true)                          \
  N(OneByteStringSetCodeUnitAt, "_OneByteString", "_setCodeUnitAt", true)      \
  N(OneByteStringSetContent, "_OneByteString", "_setContent", true)            \
  N(OneByteStringSubstring, "_OneByteString", "_substring", true)              \
                                                                               \
  N(TwoByteStringAdd, "_TwoByteString", "+", true)                             \
  N(TwoByteStringCodeUnitAt, "_TwoByteString", "codeUnitAt", true)             \
  N(TwoByteStringCreate, "_TwoByteString", "_create", true)                    \
  N(TwoByteStringEqual, "_TwoByteString", "==", true)                          \
  N(TwoByteStringSetCodeUnitAt, "_TwoByteString", "_setCodeUnitAt", true)      \
  N(TwoByteStringSetContent, "_TwoByteString", "_setContent", true)            \
  N(TwoByteStringSubstring, "_TwoByteString", "_substring", true)              \
                                                                               \
  N(UriBase, "Uri", "_base", true)                                             \
                                                                               \
  N(ProcessLink, "Process", "link", true)                                      \
  N(ProcessUnlink, "Process", "unlink", true)                                  \
  N(ProcessMonitor, "Process", "monitor", true)                                \
  N(ProcessUnmonitor, "Process", "unmonitor", true)                            \
  N(ProcessKill, "Process", "kill", true)                                      \
                                                                               \
  N(PortCreate, "Port", "_create", true)                                       \
  N(PortSend, "Port", "send", true)                                            \
  N(PortSendExit, "Port", "_sendExit", true)                                   \
                                                                               \
  N(SystemEventHandlerAdd, "EventHandler", "_eventHandlerAdd", true)           \
                                                                               \
  N(ServiceRegister, "<none>", "register", true)                               \
                                                                               \
  N(IsImmutable, "<none>", "_isImmutable", true)                               \
  N(IdentityHashCode, "<none>", "_identityHashCode", true)                     \
                                                                               \
  N(NativeProcessSpawnDetached, "NativeProcess", "_spawnDetached", true)       \
                                                                               \
  N(Uint32DigitsAllocate, "_Uint32Digits", "_allocate", true)                  \
  N(Uint32DigitsGet, "_Uint32Digits", "_getUint32", true)                      \
  N(Uint32DigitsSet, "_Uint32Digits", "_setUint32", true)

enum Native {
#define N(e, c, n, l) k##e,
  NATIVES_DO(N)
#undef N
      kNumberOfNatives
};

#define N(e, c, n, l) const bool kIsLeaf_##e = l;
NATIVES_DO(N)
#undef N


}  // namespace dartino

#endif  // SRC_SHARED_NATIVES_H_
