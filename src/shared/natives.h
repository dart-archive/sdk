// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_SHARED_NATIVES_H_
#define SRC_SHARED_NATIVES_H_

namespace fletch {

#define NATIVES_DO(N)                                                     \
  N(PrintToConsole, "<none>", "printToConsole")                           \
  N(ExposeGC, "<none>", "_exposeGC")                                      \
  N(GC, "<none>", "_gc")                                                  \
                                                                          \
  N(IntParse, "int", "_parse")                                            \
                                                                          \
  N(SmiToDouble, "_Smi", "toDouble")                                      \
  N(SmiToString, "_Smi", "toString")                                      \
  N(SmiToMint, "_Smi", "_toMint")                                         \
                                                                          \
  N(SmiNegate, "_Smi", "unary-")                                          \
                                                                          \
  N(SmiAdd, "_Smi", "+")                                                  \
  N(SmiSub, "_Smi", "-")                                                  \
  N(SmiMul, "_Smi", "*")                                                  \
  N(SmiMod, "_Smi", "%")                                                  \
  N(SmiDiv, "_Smi", "/")                                                  \
  N(SmiTruncDiv, "_Smi", "~/")                                            \
                                                                          \
  N(SmiBitNot, "_Smi", "~")                                               \
  N(SmiBitAnd, "_Smi", "&")                                               \
  N(SmiBitOr, "_Smi", "|")                                                \
  N(SmiBitXor, "_Smi", "^")                                               \
  N(SmiBitShr, "_Smi", ">>")                                              \
  N(SmiBitShl, "_Smi", "<<")                                              \
                                                                          \
  N(SmiEqual, "_Smi", "==")                                               \
  N(SmiLess, "_Smi", "<")                                                 \
  N(SmiLessEqual, "_Smi", "<=")                                           \
  N(SmiGreater, "_Smi", ">")                                              \
  N(SmiGreaterEqual, "_Smi", ">=")                                        \
                                                                          \
  N(MintToDouble, "_Mint", "toDouble")                                    \
  N(MintToString, "_Mint", "toString")                                    \
                                                                          \
  N(MintNegate, "_Mint", "unary-")                                        \
                                                                          \
  N(MintAdd, "_Mint", "+")                                                \
  N(MintSub, "_Mint", "-")                                                \
  N(MintMul, "_Mint", "*")                                                \
  N(MintMod, "_Mint", "%")                                                \
  N(MintDiv, "_Mint", "/")                                                \
  N(MintTruncDiv, "_Mint", "~/")                                          \
                                                                          \
  N(MintBitNot, "_Mint", "~")                                             \
  N(MintBitAnd, "_Mint", "&")                                             \
  N(MintBitOr, "_Mint", "|")                                              \
  N(MintBitXor, "_Mint", "^")                                             \
  N(MintBitShr, "_Mint", ">>")                                            \
  N(MintBitShl, "_Mint", "<<")                                            \
                                                                          \
  N(MintEqual, "_Mint", "==")                                             \
  N(MintLess, "_Mint", "<")                                               \
  N(MintLessEqual, "_Mint", "<=")                                         \
  N(MintGreater, "_Mint", ">")                                            \
  N(MintGreaterEqual, "_Mint", ">=")                                      \
                                                                          \
  N(DoubleNegate, "_DoubleImpl", "unary-")                                \
                                                                          \
  N(DoubleAdd, "_DoubleImpl", "+")                                        \
  N(DoubleSub, "_DoubleImpl", "-")                                        \
  N(DoubleMul, "_DoubleImpl", "*")                                        \
  N(DoubleMod, "_DoubleImpl", "%")                                        \
  N(DoubleDiv, "_DoubleImpl", "/")                                        \
  N(DoubleTruncDiv, "_DoubleImpl", "~/")                                  \
                                                                          \
  N(DoubleEqual, "_DoubleImpl", "==")                                     \
  N(DoubleLess, "_DoubleImpl", "<")                                       \
  N(DoubleLessEqual, "_DoubleImpl", "<=")                                 \
  N(DoubleGreater, "_DoubleImpl", ">")                                    \
  N(DoubleGreaterEqual, "_DoubleImpl", ">=")                              \
                                                                          \
  N(DoubleIsNaN, "_DoubleImpl", "isNaN")                                  \
  N(DoubleIsNegative, "_DoubleImpl", "isNegative")                        \
                                                                          \
  N(DoubleCeil, "_DoubleImpl", "ceil")                                    \
  N(DoubleCeilToDouble, "_DoubleImpl", "ceilToDouble")                    \
  N(DoubleRound, "_DoubleImpl", "round")                                  \
  N(DoubleRoundToDouble, "_DoubleImpl", "roundToDouble")                  \
  N(DoubleFloor, "_DoubleImpl", "floor")                                  \
  N(DoubleFloorToDouble, "_DoubleImpl", "floorToDouble")                  \
  N(DoubleTruncate, "_DoubleImpl", "truncate")                            \
  N(DoubleTruncateToDouble, "_DoubleImpl", "truncateToDouble")            \
  N(DoubleRemainder, "_DoubleImpl", "remainder")                          \
  N(DoubleToInt, "_DoubleImpl", "toInt")                                  \
  N(DoubleToString, "_DoubleImpl", "toString")                            \
  N(DoubleToStringAsExponential, "_DoubleImpl", "_toStringAsExponential") \
  N(DoubleToStringAsFixed, "_DoubleImpl", "_toStringAsFixed")             \
  N(DoubleToStringAsPrecision, "_DoubleImpl", "_toStringAsPrecision")     \
                                                                          \
  N(DoubleParse, "double", "_parse")                                      \
                                                                          \
  N(DoubleSin, "<none>", "_sin")                                          \
  N(DoubleCos, "<none>", "_cos")                                          \
  N(DoubleTan, "<none>", "_tan")                                          \
  N(DoubleAcos, "<none>", "_acos")                                        \
  N(DoubleAsin, "<none>", "_asin")                                        \
  N(DoubleAtan, "<none>", "_atan")                                        \
  N(DoubleSqrt, "<none>", "_sqrt")                                        \
  N(DoubleExp, "<none>", "_exp")                                          \
  N(DoubleLog, "<none>", "_log")                                          \
  N(DoubleAtan2, "<none>", "_atan2")                                      \
  N(DoublePow, "<none>", "_pow")                                          \
                                                                          \
  N(DateTimeGetCurrentMs, "DateTime", "_getCurrentMs")                    \
  N(DateTimeTimeZone, "DateTime", "_timeZone")                            \
  N(DateTimeTimeZoneOffset, "DateTime", "_timeZoneOffset")                \
  N(DateTimeLocalTimeZoneOffset, "DateTime", "_localTimeZoneOffset")      \
                                                                          \
  N(ListNew, "_FixedListBase", "_new")                                    \
  N(ListLength, "_FixedListBase", "length")                               \
  N(ListIndexGet, "_FixedListBase", "[]")                                 \
                                                                          \
  N(ByteListIndexGet, "_ConstantByteList", "[]")                          \
                                                                          \
  N(ListIndexSet, "_FixedList", "[]=")                                    \
                                                                          \
  N(ProcessSpawn, "Process", "_spawn")                                    \
  N(ProcessQueueGetMessage, "Process", "_queueGetMessage")                \
  N(ProcessQueueGetChannel, "Process", "_queueGetChannel")                \
  N(ProcessCurrent, "Process", "current")                                 \
                                                                          \
  N(CoroutineCurrent, "Coroutine", "_coroutineCurrent")                   \
  N(CoroutineNewStack, "Coroutine", "_coroutineNewStack")                 \
                                                                          \
  N(StopwatchFrequency, "Stopwatch", "_frequency")                        \
  N(StopwatchNow, "Stopwatch", "_now")                                    \
                                                                          \
  N(TimerScheduleTimeout, "_FletchTimer", "_scheduleTimeout")             \
                                                                          \
  N(EventHandlerAdd, "<none>", "_eventHandlerAdd")                        \
                                                                          \
  N(ForeignLibraryLookup, "ForeignLibrary", "_lookupLibrary")             \
  N(ForeignLibraryClose, "ForeignLibrary", "_closeLibrary")               \
  N(ForeignLibraryGetFunction, "ForeignLibrary", "_lookupFunction")       \
  N(ForeignLibraryBundlePath, "ForeignLibrary", "bundleLibraryName")      \
                                                                          \
  N(ForeignBitsPerWord, "Foreign", "_bitsPerMachineWord")                 \
  N(ForeignErrno, "Foreign", "_errno")                                    \
  N(ForeignPlatform, "Foreign", "_platform")                              \
  N(ForeignArchitecture, "Foreign", "_architecture")                      \
  N(ForeignConvertPort, "Foreign", "_convertPort")                        \
                                                                          \
  N(ForeignICall0, "ForeignFunction", "_icall$0")                         \
  N(ForeignICall1, "ForeignFunction", "_icall$1")                         \
  N(ForeignICall2, "ForeignFunction", "_icall$2")                         \
  N(ForeignICall3, "ForeignFunction", "_icall$3")                         \
  N(ForeignICall4, "ForeignFunction", "_icall$4")                         \
  N(ForeignICall5, "ForeignFunction", "_icall$5")                         \
  N(ForeignICall6, "ForeignFunction", "_icall$6")                         \
  N(ForeignICall7, "ForeignFunction", "_icall$7")                         \
                                                                          \
  N(ForeignPCall0, "ForeignFunction", "_pcall$0")                         \
  N(ForeignPCall1, "ForeignFunction", "_pcall$1")                         \
  N(ForeignPCall2, "ForeignFunction", "_pcall$2")                         \
  N(ForeignPCall3, "ForeignFunction", "_pcall$3")                         \
  N(ForeignPCall4, "ForeignFunction", "_pcall$4")                         \
  N(ForeignPCall5, "ForeignFunction", "_pcall$5")                         \
  N(ForeignPCall6, "ForeignFunction", "_pcall$6")                         \
                                                                          \
  N(ForeignVCall0, "ForeignFunction", "_vcall$0")                         \
  N(ForeignVCall1, "ForeignFunction", "_vcall$1")                         \
  N(ForeignVCall2, "ForeignFunction", "_vcall$2")                         \
  N(ForeignVCall3, "ForeignFunction", "_vcall$3")                         \
  N(ForeignVCall4, "ForeignFunction", "_vcall$4")                         \
  N(ForeignVCall5, "ForeignFunction", "_vcall$5")                         \
  N(ForeignVCall6, "ForeignFunction", "_vcall$6")                         \
                                                                          \
  N(ForeignLCallwLw, "ForeignFunction", "_Lcall$wLw")                     \
                                                                          \
  N(ForeignDecreaseMemoryUsage, "ForeignMemory", "_decreaseMemoryUsage")  \
  N(ForeignMarkForFinalization, "UnsafeMemory", "_markForFinalization")   \
  N(ForeignAllocate, "UnsafeMemory", "_allocate")                         \
                                                                          \
  N(ForeignGetInt8, "UnsafeMemory", "_getInt8")                           \
  N(ForeignGetInt16, "UnsafeMemory", "_getInt16")                         \
  N(ForeignGetInt32, "UnsafeMemory", "_getInt32")                         \
  N(ForeignGetInt64, "UnsafeMemory", "_getInt64")                         \
                                                                          \
  N(ForeignSetInt8, "UnsafeMemory", "_setInt8")                           \
  N(ForeignSetInt16, "UnsafeMemory", "_setInt16")                         \
  N(ForeignSetInt32, "UnsafeMemory", "_setInt32")                         \
  N(ForeignSetInt64, "UnsafeMemory", "_setInt64")                         \
                                                                          \
  N(ForeignGetUint8, "UnsafeMemory", "_getUint8")                         \
  N(ForeignGetUint16, "UnsafeMemory", "_getUint16")                       \
  N(ForeignGetUint32, "UnsafeMemory", "_getUint32")                       \
  N(ForeignGetUint64, "UnsafeMemory", "_getUint64")                       \
                                                                          \
  N(ForeignSetUint8, "UnsafeMemory", "_setUint8")                         \
  N(ForeignSetUint16, "UnsafeMemory", "_setUint16")                       \
  N(ForeignSetUint32, "UnsafeMemory", "_setUint32")                       \
  N(ForeignSetUint64, "UnsafeMemory", "_setUint64")                       \
                                                                          \
  N(ForeignGetFloat32, "UnsafeMemory", "_getFloat32")                     \
  N(ForeignGetFloat64, "UnsafeMemory", "_getFloat64")                     \
                                                                          \
  N(ForeignSetFloat32, "UnsafeMemory", "_setFloat32")                     \
  N(ForeignSetFloat64, "UnsafeMemory", "_setFloat64")                     \
                                                                          \
  N(ForeignFree, "ForeignMemory", "_free")                                \
                                                                          \
  N(StringLength, "_StringBase", "length")                                \
                                                                          \
  N(OneByteStringAdd, "_OneByteString", "+")                              \
  N(OneByteStringCodeUnitAt, "_OneByteString", "codeUnitAt")              \
  N(OneByteStringCreate, "_OneByteString", "_create")                     \
  N(OneByteStringEqual, "_OneByteString", "==")                           \
  N(OneByteStringSetCodeUnitAt, "_OneByteString", "_setCodeUnitAt")       \
  N(OneByteStringSetContent, "_OneByteString", "_setContent")             \
  N(OneByteStringSubstring, "_OneByteString", "_substring")               \
                                                                          \
  N(TwoByteStringAdd, "_TwoByteString", "+")                              \
  N(TwoByteStringCodeUnitAt, "_TwoByteString", "codeUnitAt")              \
  N(TwoByteStringCreate, "_TwoByteString", "_create")                     \
  N(TwoByteStringEqual, "_TwoByteString", "==")                           \
  N(TwoByteStringSetCodeUnitAt, "_TwoByteString", "_setCodeUnitAt")       \
  N(TwoByteStringSetContent, "_TwoByteString", "_setContent")             \
  N(TwoByteStringSubstring, "_TwoByteString", "_substring")               \
                                                                          \
  N(UriBase, "Uri", "_base")                                              \
                                                                          \
  N(ProcessLink, "Process", "link")                                       \
  N(ProcessUnlink, "Process", "unlink")                                   \
  N(ProcessMonitor, "Process", "monitor")                                 \
  N(ProcessUnmonitor, "Process", "unmonitor")                             \
                                                                          \
  N(PortCreate, "Port", "_create")                                        \
  N(PortSend, "Port", "send")                                             \
  N(PortSendExit, "Port", "_sendExit")                                    \
                                                                          \
  N(SystemGetEventHandler, "EventHandler", "_getEventHandler")            \
  N(SystemIncrementPortRef, "EventHandler", "_incrementPortRef")          \
                                                                          \
  N(ServiceRegister, "<none>", "register")                                \
                                                                          \
  N(IsImmutable, "<none>", "_isImmutable")                                \
  N(IdentityHashCode, "<none>", "_identityHashCode")                      \
                                                                          \
  N(NativeProcessSpawnDetached, "NativeProcess", "_spawnDetached")        \
                                                                          \
  N(Uint32DigitsAllocate, "_Uint32Digits", "_allocate")                   \
  N(Uint32DigitsGet, "_Uint32Digits", "_getUint32")                       \
  N(Uint32DigitsSet, "_Uint32Digits", "_setUint32")

enum Native {
#define N(e, c, n) k##e,
  NATIVES_DO(N)
#undef N
      kNumberOfNatives
};

}  // namespace fletch

#endif  // SRC_SHARED_NATIVES_H_
