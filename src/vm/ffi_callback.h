// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_FFI_CALLBACK_H_
#define SRC_VM_FFI_CALLBACK_H_

#include "src/shared/globals.h"

namespace dartino {

// Forward-declarations.
class ProcessHandle;

class CallbackStub {
 public:
  explicit CallbackStub(void* fun)
      : handle(NULL),
        callback_id(-1),
        error_value(-1),
        function(fun) {}

  ProcessHandle* handle;
  word callback_id;
  word error_value;
  void* function;
};

#define FFI_CALLBACKS_WITH_ARITY_DO(arity, A0) \
  A0(arity, 0) \
  A0(arity, 1) \
  A0(arity, 2) \
  A0(arity, 3)

#define CALLBACKS_PER_ARITY 4

#define FFI_CALLBACKS_DO(A0, A1, A2, A3) \
  FFI_CALLBACKS_WITH_ARITY_DO(0, A0) \
  FFI_CALLBACKS_WITH_ARITY_DO(1, A1) \
  FFI_CALLBACKS_WITH_ARITY_DO(2, A2) \
  FFI_CALLBACKS_WITH_ARITY_DO(3, A3)

#define FFI_ALL_CALLBACKS_DO(A) FFI_CALLBACKS_DO(A, A, A, A)

// Macro to forward declare the callbacks.
#define DECLARE_CALLBACK_STUB_0_N(arity, id) \
  extern "C" word ffi_callback_0_##id##_();

#define DECLARE_CALLBACK_STUB_1_N(arity, id) \
  extern "C" word ffi_callback_1_##id##_(word arg0);

#define DECLARE_CALLBACK_STUB_2_N(arity, id) \
  extern "C" word ffi_callback_2_##id##_(word arg0, word arg1);

#define DECLARE_CALLBACK_STUB_3_N(arity, id) \
  extern "C" word ffi_callback_3_##id##_(word arg0, word arg1, word arg2);

// Definitions of the callbacks.
#define DEFINE_CALLBACK_STUB_0_N(arity, id)                           \
  extern "C" word ffi_callback_0_##id##_() {                          \
    CallbackStub& data = ffi_stubs[arity][id];                        \
    return DoFfiCallback(                                             \
        0, data.handle, data.callback_id, 0, 0, 0, data.error_value); \
  }

#define DEFINE_CALLBACK_STUB_1_N(arity, id)                              \
  extern "C" word ffi_callback_1_##id##_(word arg0) {                    \
    CallbackStub& data = ffi_stubs[arity][id];                           \
    return DoFfiCallback(                                                \
        1, data.handle, data.callback_id, arg0, 0, 0, data.error_value); \
  }

#define DEFINE_CALLBACK_STUB_2_N(arity, id)                                 \
  extern "C" word ffi_callback_2_##id##_(word arg0, word arg1) {            \
    CallbackStub& data = ffi_stubs[arity][id];                              \
    return DoFfiCallback(                                                   \
        2, data.handle, data.callback_id, arg0, arg1, 0, data.error_value); \
  }

#define DEFINE_CALLBACK_STUB_3_N(arity, id)                                    \
  extern "C" word ffi_callback_3_##id##_(word arg0, word arg1, word arg2) {    \
    CallbackStub& data = ffi_stubs[arity][id];                                 \
    return DoFfiCallback(                                                      \
        3, data.handle, data.callback_id, arg0, arg1, arg2, data.error_value); \
  }

// The array that holds all the data.
#define DEFINE_CALLBACK_STUB_STRUCT(arity, id) \
    CallbackStub(reinterpret_cast<void*>(&ffi_callback_##arity##_##id##_)),

#define DEFINE_CALLBACK_STUB_ARRAY                                  \
  static CallbackStub ffi_stubs[][CALLBACKS_PER_ARITY] = {          \
    { FFI_CALLBACKS_WITH_ARITY_DO(0, DEFINE_CALLBACK_STUB_STRUCT)}, \
    { FFI_CALLBACKS_WITH_ARITY_DO(1, DEFINE_CALLBACK_STUB_STRUCT)}, \
    { FFI_CALLBACKS_WITH_ARITY_DO(2, DEFINE_CALLBACK_STUB_STRUCT)}, \
    { FFI_CALLBACKS_WITH_ARITY_DO(3, DEFINE_CALLBACK_STUB_STRUCT)}, \
  };

}  // namespace dartino

#endif  // SRC_VM_FFI_CALLBACK_H_
