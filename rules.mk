# Makefile for building the Dartino VM as an LK [1] module.
#
# This builds the Dartino VM from source with the LK build system, and
# require g++, python and git to be installed on the host.
#
# As part of the build a tool (dartino_vm_library_generator) is
# compiled on the host. This requires that g++ in installed on the
# host.
#
# The build also generated the Dartino VM version from the information
# in tools/VERSION possibly combined with the git revision. This
# requires python anf git to be installed on the host.
#
# [1] https://github.com/littlekernel/lk).

OS := $(shell uname)

DARTINO_ROOT := $(GET_LOCAL_DIR)

DARTINO_SRC_VM := $(DARTINO_ROOT)/src/vm
DARTINO_SRC_SHARED := $(DARTINO_ROOT)/src/shared
DARTINO_SRC_DOUBLE_CONVERSION := $(DARTINO_ROOT)/third_party/double-conversion/src
DARTINO_SRC_FLASHTOOL := $(DARTINO_ROOT)/src/tools/flashtool

# The split between runtime and interpreter is somewhat arbitrary. The goal
# is to be able to build a host version of the runtime part that suffices
# to build the flashtool helper. So as long as flashtool still builds in
# a crosscompilation setting it does not matter where a new file goes.
DARTINO_SRC_VM_SRCS_RUNTIME := \
	$(DARTINO_SRC_VM)/dartino_api_impl.cc \
	$(DARTINO_SRC_VM)/dartino_api_impl.h \
	$(DARTINO_SRC_VM)/dartino.cc \
	$(DARTINO_SRC_VM)/debug_info.cc \
	$(DARTINO_SRC_VM)/debug_info.h \
	$(DARTINO_SRC_VM)/debug_info_no_debugging.h \
	$(DARTINO_SRC_VM)/dispatch_table.cc \
	$(DARTINO_SRC_VM)/dispatch_table.h \
	$(DARTINO_SRC_VM)/dispatch_table_debugging.h \
	$(DARTINO_SRC_VM)/double_list.h \
	$(DARTINO_SRC_VM)/event_handler.cc \
	$(DARTINO_SRC_VM)/event_handler_cmsis.cc \
	$(DARTINO_SRC_VM)/event_handler.h \
	$(DARTINO_SRC_VM)/event_handler_linux.cc \
	$(DARTINO_SRC_VM)/event_handler_lk.cc \
	$(DARTINO_SRC_VM)/event_handler_macos.cc \
	$(DARTINO_SRC_VM)/event_handler_posix.cc \
	$(DARTINO_SRC_VM)/event_handler_windows.cc \
	$(DARTINO_SRC_VM)/gc_metadata.cc \
	$(DARTINO_SRC_VM)/gc_metadata.h \
	$(DARTINO_SRC_VM)/hash_map.h \
	$(DARTINO_SRC_VM)/hash_set.h \
	$(DARTINO_SRC_VM)/hash_table.h \
	$(DARTINO_SRC_VM)/heap.cc \
	$(DARTINO_SRC_VM)/heap.h \
	$(DARTINO_SRC_VM)/heap_validator.cc \
	$(DARTINO_SRC_VM)/heap_validator.h \
	$(DARTINO_SRC_VM)/intrinsics.cc \
	$(DARTINO_SRC_VM)/intrinsics.h \
	$(DARTINO_SRC_VM)/links.cc \
	$(DARTINO_SRC_VM)/links.h \
	$(DARTINO_SRC_VM)/log_print_interceptor.cc \
	$(DARTINO_SRC_VM)/log_print_interceptor.h \
	$(DARTINO_SRC_VM)/lookup_cache.cc \
	$(DARTINO_SRC_VM)/lookup_cache.h \
	$(DARTINO_SRC_VM)/mailbox.h \
	$(DARTINO_SRC_VM)/message_mailbox.cc \
	$(DARTINO_SRC_VM)/message_mailbox.h \
	$(DARTINO_SRC_VM)/multi_hashset.h \
	$(DARTINO_SRC_VM)/native_process_disabled.cc \
	$(DARTINO_SRC_VM)/native_process_posix.cc \
	$(DARTINO_SRC_VM)/native_process_windows.cc \
	$(DARTINO_SRC_VM)/natives.cc \
	$(DARTINO_SRC_VM)/natives_cmsis.cc \
	$(DARTINO_SRC_VM)/natives.h \
	$(DARTINO_SRC_VM)/natives_lk.cc \
	$(DARTINO_SRC_VM)/natives_posix.cc \
	$(DARTINO_SRC_VM)/natives_windows.cc \
	$(DARTINO_SRC_VM)/object.cc \
	$(DARTINO_SRC_VM)/object.h \
	$(DARTINO_SRC_VM)/object_list.cc \
	$(DARTINO_SRC_VM)/object_list.h \
	$(DARTINO_SRC_VM)/object_map.cc \
	$(DARTINO_SRC_VM)/object_map.h \
	$(DARTINO_SRC_VM)/object_memory.cc \
	$(DARTINO_SRC_VM)/object_memory_copying.cc \
	$(DARTINO_SRC_VM)/object_memory.h \
	$(DARTINO_SRC_VM)/object_memory_mark_sweep.cc \
	$(DARTINO_SRC_VM)/pair.h \
	$(DARTINO_SRC_VM)/port.cc \
	$(DARTINO_SRC_VM)/port.h \
	$(DARTINO_SRC_VM)/priority_heap.h \
	$(DARTINO_SRC_VM)/process.cc \
	$(DARTINO_SRC_VM)/process.h \
	$(DARTINO_SRC_VM)/process_handle.cc \
	$(DARTINO_SRC_VM)/process_handle.h \
	$(DARTINO_SRC_VM)/process_queue.h \
	$(DARTINO_SRC_VM)/program.cc \
	$(DARTINO_SRC_VM)/program_folder.cc \
	$(DARTINO_SRC_VM)/program_folder.h \
	$(DARTINO_SRC_VM)/program_folder_no_live_coding.h \
	$(DARTINO_SRC_VM)/program_groups.cc \
	$(DARTINO_SRC_VM)/program_groups.h \
	$(DARTINO_SRC_VM)/program.h \
	$(DARTINO_SRC_VM)/program_info_block.cc \
	$(DARTINO_SRC_VM)/program_info_block.h \
	$(DARTINO_SRC_VM)/scheduler.cc \
	$(DARTINO_SRC_VM)/scheduler.h \
	$(DARTINO_SRC_VM)/selector_row.cc \
	$(DARTINO_SRC_VM)/selector_row.h \
	$(DARTINO_SRC_VM)/service_api_impl.cc \
	$(DARTINO_SRC_VM)/service_api_impl.h \
	$(DARTINO_SRC_VM)/session.cc \
	$(DARTINO_SRC_VM)/session.h \
	$(DARTINO_SRC_VM)/session_no_debugging.h \
	$(DARTINO_SRC_VM)/signal.h \
	$(DARTINO_SRC_VM)/snapshot.cc \
	$(DARTINO_SRC_VM)/snapshot.h \
	$(DARTINO_SRC_VM)/sort.cc \
	$(DARTINO_SRC_VM)/sort.h \
	$(DARTINO_SRC_VM)/thread_cmsis.cc \
	$(DARTINO_SRC_VM)/thread_cmsis.h \
	$(DARTINO_SRC_VM)/thread.h \
	$(DARTINO_SRC_VM)/thread_lk.cc \
	$(DARTINO_SRC_VM)/thread_lk.h \
	$(DARTINO_SRC_VM)/thread_pool.cc \
	$(DARTINO_SRC_VM)/thread_pool.h \
	$(DARTINO_SRC_VM)/thread_posix.cc \
	$(DARTINO_SRC_VM)/thread_posix.h \
	$(DARTINO_SRC_VM)/thread_windows.cc \
	$(DARTINO_SRC_VM)/thread_windows.h \
	$(DARTINO_SRC_VM)/unicode.cc \
	$(DARTINO_SRC_VM)/unicode.h \
	$(DARTINO_SRC_VM)/vector.cc \
	$(DARTINO_SRC_VM)/vector.h \
	$(DARTINO_SRC_VM)/void_hash_table.cc \
	$(DARTINO_SRC_VM)/void_hash_table.h \
	$(DARTINO_SRC_VM)/weak_pointer.cc \
	$(DARTINO_SRC_VM)/weak_pointer.h

ifeq ($(DARTINO_ENABLE_SOCKETS),1)
DARTINO_SRC_VM_SRCS_RUNTIME += \
	$(DARTINO_SRC_VM)/socket_connection_api_impl.cc \
	$(DARTINO_SRC_VM)/socket_connection_api_impl.h
endif

DARTINO_SRC_VM_SRCS_INTERPRETER := \
	$(DARTINO_SRC_VM)/ffi.cc \
	$(DARTINO_SRC_VM)/ffi.h \
	$(DARTINO_SRC_VM)/ffi_callback.cc \
	$(DARTINO_SRC_VM)/ffi_callback.h \
	$(DARTINO_SRC_VM)/ffi_disabled.cc \
	$(DARTINO_SRC_VM)/ffi_linux.cc \
	$(DARTINO_SRC_VM)/ffi_macos.cc \
	$(DARTINO_SRC_VM)/ffi_posix.cc \
	$(DARTINO_SRC_VM)/ffi_static.cc \
	$(DARTINO_SRC_VM)/ffi_windows.cc \
	$(DARTINO_SRC_VM)/interpreter.cc \
	$(DARTINO_SRC_VM)/interpreter.h \
	$(DARTINO_SRC_VM)/native_interpreter.cc \
	$(DARTINO_SRC_VM)/native_interpreter.h \
	$(DARTINO_SRC_VM)/preempter.cc \
	$(DARTINO_SRC_VM)/preempter.h \
	$(DARTINO_SRC_VM)/tick_queue.h \
	$(DARTINO_SRC_VM)/tick_sampler.h \
	$(DARTINO_SRC_VM)/tick_sampler_other.cc \
	$(DARTINO_SRC_VM)/tick_sampler_posix.cc

# The file program_info_block.h is included to detect interface changes.
DARTINO_SRC_RELOCATION_SRCS := \
	$(DARTINO_SRC_VM)/dartino_relocation_api_impl.cc \
	$(DARTINO_SRC_VM)/dartino_relocation_api_impl.h \
	$(DARTINO_SRC_VM)/program_info_block.h \
	$(DARTINO_SRC_VM)/program_relocator.cc \
	$(DARTINO_SRC_VM)/program_relocator.h

DARTINO_SRC_SHARED_SRCS := \
	$(DARTINO_SRC_SHARED)/asan_helper.h \
	$(DARTINO_SRC_SHARED)/assert.cc \
	$(DARTINO_SRC_SHARED)/assert.h \
	$(DARTINO_SRC_SHARED)/atomic.h \
	$(DARTINO_SRC_SHARED)/bytecodes.cc \
	$(DARTINO_SRC_SHARED)/bytecodes.h \
	$(DARTINO_SRC_SHARED)/connection.cc \
	$(DARTINO_SRC_SHARED)/connection.h \
	$(DARTINO_SRC_SHARED)/flags.cc \
	$(DARTINO_SRC_SHARED)/flags.h \
	$(DARTINO_SRC_SHARED)/dartino.h \
	$(DARTINO_SRC_SHARED)/globals.h \
	$(DARTINO_SRC_SHARED)/list.h \
	$(DARTINO_SRC_SHARED)/names.h \
	$(DARTINO_SRC_SHARED)/platform.h \
	$(DARTINO_SRC_SHARED)/platform_linux.cc \
	$(DARTINO_SRC_SHARED)/platform_lk.cc \
	$(DARTINO_SRC_SHARED)/platform_lk.h \
	$(DARTINO_SRC_SHARED)/platform_macos.cc \
	$(DARTINO_SRC_SHARED)/platform_cmsis.cc \
	$(DARTINO_SRC_SHARED)/platform_cmsis.h \
	$(DARTINO_SRC_SHARED)/platform_posix.cc \
	$(DARTINO_SRC_SHARED)/platform_posix.h \
	$(DARTINO_SRC_SHARED)/platform_vm.cc \
	$(DARTINO_SRC_SHARED)/platform_windows.cc \
	$(DARTINO_SRC_SHARED)/platform_windows.h \
	$(DARTINO_SRC_SHARED)/random.h \
	$(DARTINO_SRC_SHARED)/selectors.h \
	$(DARTINO_SRC_SHARED)/utils.cc \
	$(DARTINO_SRC_SHARED)/utils.h \
	$(DARTINO_SRC_SHARED)/version.h

ifeq ($(DARTINO_ENABLE_SOCKETS),1)
DARTINO_SRC_SHARED_SRCS += \
	$(DARTINO_SRC_SHARED)/native_socket.h \
	$(DARTINO_SRC_SHARED)/native_socket_linux.cc \
	$(DARTINO_SRC_SHARED)/native_socket_lk.cc \
	$(DARTINO_SRC_SHARED)/native_socket_macos.cc \
	$(DARTINO_SRC_SHARED)/native_socket_posix.cc \
	$(DARTINO_SRC_SHARED)/native_socket_windows.cc \
	$(DARTINO_SRC_SHARED)/natives.h \
	$(DARTINO_SRC_SHARED)/socket_connection.cc \
	$(DARTINO_SRC_SHARED)/socket_connection.h
endif

DARTINO_SRC_DOUBLE_CONVERSION_SRCS := \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/bignum-dtoa.cc \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/bignum-dtoa.h \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/bignum.cc \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/bignum.h \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/cached-powers.cc \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/cached-powers.h \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/diy-fp.cc \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/diy-fp.h \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/double-conversion.cc \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/double-conversion.h \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/ieee.h \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/strtod.cc \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/strtod.h \
	$(DARTINO_SRC_DOUBLE_CONVERSION)/utils.h

MODULE := $(DARTINO_ROOT)

MODULE_DEFINES += \
	DARTINO32 \
	DARTINO_USE_SINGLE_PRECISION \
	DARTINO_TARGET_ARM \
	DARTINO_THUMB_ONLY \
	DARTINO_TARGET_OS_LK \
	DARTINO_ENABLE_FFI \
	DARTINO_ENABLE_DEBUGGING

ifneq ($(DEBUG),)
MODULE_DEFINES += DEBUG
endif

MODULE_CFLAGS += \
	--std=c99 \
	-fvisibility=hidden \
	-fno-exceptions \
	-fno-strict-aliasing

MODULE_CPPFLAGS += \
	--std=c++11 \
	-Werror \
	-Wno-invalid-offsetof \
	-fvisibility=hidden \
	-fno-rtti \
	-fno-exceptions \
	-fno-strict-aliasing

MODULE_INCLUDES += $(DARTINO_ROOT)

MODULE_SRCS := \
	$(DARTINO_SRC_VM_SRCS_RUNTIME) \
	$(DARTINO_SRC_VM_SRCS_INTERPRETER) \
	$(DARTINO_SRC_SHARED_SRCS) \
	$(DARTINO_SRC_DOUBLE_CONVERSION_SRCS) \
	$(BUILDDIR)/version.cc \
	$(BUILDDIR)/generated.S

#
# This is the part for building host-tools and generating generated.S
# and version.cc on the host. Generating generated.S requires a host
# build of dartino_vm_library_generator.
#

# Sources for the dartino_vm_library_generator host-tool.
LIBRARY_GENERATOR_SRCS := \
	$(DARTINO_SRC_SHARED_SRCS) \
	$(DARTINO_SRC_VM)/assembler_arm64_linux.cc \
	$(DARTINO_SRC_VM)/assembler_arm64_macos.cc \
	$(DARTINO_SRC_VM)/assembler_arm.cc \
	$(DARTINO_SRC_VM)/assembler_arm.h \
	$(DARTINO_SRC_VM)/assembler_arm_thumb_linux.cc \
	$(DARTINO_SRC_VM)/assembler_arm_linux.cc \
	$(DARTINO_SRC_VM)/assembler_arm_thumb_macos.cc \
	$(DARTINO_SRC_VM)/assembler_arm_macos.cc \
	$(DARTINO_SRC_VM)/assembler.h \
	$(DARTINO_SRC_VM)/assembler_mips.cc \
	$(DARTINO_SRC_VM)/assembler_mips.h \
	$(DARTINO_SRC_VM)/assembler_mips_linux.cc \
	$(DARTINO_SRC_VM)/assembler_x64.cc \
	$(DARTINO_SRC_VM)/assembler_x64.h \
	$(DARTINO_SRC_VM)/assembler_x64_linux.cc \
	$(DARTINO_SRC_VM)/assembler_x64_macos.cc \
	$(DARTINO_SRC_VM)/assembler_x86.cc \
	$(DARTINO_SRC_VM)/assembler_x86.h \
	$(DARTINO_SRC_VM)/assembler_x86_linux.cc \
	$(DARTINO_SRC_VM)/assembler_x86_macos.cc \
	$(DARTINO_SRC_VM)/assembler_x86_win.cc \
	$(DARTINO_SRC_VM)/ffi_bridge_arm.cc \
	$(DARTINO_SRC_VM)/ffi_bridge_mips.cc \
	$(DARTINO_SRC_VM)/ffi_bridge_x64.cc \
	$(DARTINO_SRC_VM)/ffi_bridge_x86.cc \
	$(DARTINO_SRC_VM)/generator.h \
	$(DARTINO_SRC_VM)/generator.cc \
	$(DARTINO_SRC_VM)/interpreter_arm.cc \
	$(DARTINO_SRC_VM)/interpreter_mips.cc \
	$(DARTINO_SRC_VM)/interpreter_x86.cc \
	$(DARTINO_SRC_VM)/interpreter_x64.cc


# Sources for the flashtool host-tool.
FLASHTOOL_SRCS := \
	$(DARTINO_SRC_VM_SRCS_RUNTIME) \
	$(DARTINO_SRC_SHARED_SRCS) \
	$(DARTINO_SRC_RELOCATION_SRCS) \
	$(DARTINO_SRC_FLASHTOOL)/main.cc \
	$(BUILDDIR)/version.cc

# Combined sources for all host-tools.
HOST_TOOLS_SRCS := \
	$(LIBRARY_GENERATOR_SRCS) \
	$(FLASHTOOL_SRCS)

# Defines for compiling host-tools.
HOST_DEFINES := \
	-DDARTINO_ENABLE_LIVE_CODING \
	-DDARTINO_ENABLE_FFI \
	-DDARTINO_ENABLE_NATIVE_PROCESSES \
	-DDARTINO_ENABLE_PRINT_INTERCEPTORS \
	-DDARTINO_TARGET_OS_POSIX \
	-DDARTINO32 \
	-DDARTINO_USE_SINGLE_PRECISION \
	-DDARTINO_TARGET_ARM \
	-DDARTINO_THUMB_ONLY

ifeq ($(OS),Darwin)
HOST_DEFINES += \
	-DDARTINO_TARGET_OS_MACOS
else
HOST_DEFINES += \
	-DDARTINO_TARGET_OS_LINUX
endif

# Flags for compiling host-tools.
HOST_CPPFLAGS += \
	--std=c++11 \
	-m32 \
	-mfpmath=sse \
	-msse2 \
	-O3 \
	-fno-strict-aliasing \
	-fPIC \
	-Wall \
	-Wextra \
	-Wno-unused-parameter \
	-Wno-format \
	-Wno-comment \
	-Wno-non-virtual-dtor \
	-Werror \
	-Wno-invalid-offsetof \
	-fno-rtti \
	-fno-exceptions

# Flags for linking host-tools.
HOST_LDFLAGS := \
	-m32

ifeq ($(OS),Darwin)
HOST_LDFLAGS += \
	-Wl,-dead_strip
else
HOST_LDFLAGS += \
	-Wl,--gc-sections
endif

HOST_BUILDDIR := $(BUILDDIR)-host
TOHOSTBUILDDIR = $(addprefix $(HOST_BUILDDIR)/,$(1))

# Rules for building the dartino_vm_library_generator host-tool.
LIBRARY_GENERATOR_TOOL := $(HOST_BUILDDIR)/dartino_vm_library_generator
LIBRARY_GENERATOR_CCSRCS := $(filter %.cc,$(LIBRARY_GENERATOR_SRCS))
LIBRARY_GENERATOR_CCOBJS := $(call TOHOSTBUILDDIR,$(patsubst %.cc,%.o,$(LIBRARY_GENERATOR_CCSRCS)))
HOST_TOOLS_CCOBJS += $(LIBRARY_GENERATOR_CCOBJS)
HOST_TOOLS_DEPS += $(LIBRARY_GENERATOR_CCOBJS:%o=%d)

$(LIBRARY_GENERATOR_CCOBJS): $(HOST_BUILDDIR)/%.o: %.cc
	@$(MKDIR)
	@echo host compiling $<
	$(NOECHO)g++ $(HOST_CPPFLAGS) $(HOST_DEFINES) -I$(DARTINO_ROOT) -c $< -MD -MP -MT $@ -MF $(@:%o=%d) -o $@

$(LIBRARY_GENERATOR_TOOL): $(LIBRARY_GENERATOR_CCOBJS)
	@echo host linking $@
	$(NOECHO)g++ $(HOST_LDFLAGS) -o $(LIBRARY_GENERATOR_TOOL) $(LIBRARY_GENERATOR_CCOBJS) -lpthread

HOST_GENERATED += $(LIBRARY_GENERATOR_TOOL)

$(BUILDDIR)/generated.S: $(LIBRARY_GENERATOR_TOOL)
	@$(MKDIR)
	@echo generating $@
	$(LIBRARY_GENERATOR_TOOL) $(BUILDDIR)/generated.S

HOST_GENERATED += $(BUILDDIR)/generated.S

DARTINO_GENERATE_VERSION := $(DARTINO_ROOT)/tools/generate_version_cc.py

# Rules for building $(BUILDDIR)/version.cc.
# TODO(473): Find a way to make building
# version.cc dependent in something which works for submodule checkout.
force_version_cc:
$(BUILDDIR)/version.cc: force_version_cc
	@$(MKDIR)
	@echo generating $@
	python $(DARTINO_GENERATE_VERSION) $(DARTINO_ROOT)/.git/logs/HEAD $(DARTINO_ROOT)/.git/HEAD $(BUILDDIR)/version.cc

HOST_GENERATED += $(BUILDDIR)/version.cc

# Rules for building the flashtool host-tool.
FLASHTOOL_TOOL := $(HOST_BUILDDIR)/flashtool
FLASHTOOL_CCSRCS := $(filter %.cc,$(FLASHTOOL_SRCS))
FLASHTOOL_CCOBJS := $(call TOHOSTBUILDDIR,$(patsubst %.cc,%.o,$(FLASHTOOL_CCSRCS)))
HOST_TOOLS_CCOBJS += $(FLASHTOOL_CCOBJS)
HOST_TOOLS_DEPS += $(FLASHTOOL_CCOBJS:%o=%d)

$(FLASHTOOL_CCOBJS): $(HOST_BUILDDIR)/%.o: %.cc
	@$(MKDIR)
	@echo host compiling $<
	$(NOECHO)g++ $(HOST_CPPFLAGS) $(HOST_DEFINES) -I$(DARTINO_ROOT) -c $< -MD -MP -MT $@ -MF $(@:%o=%d) -o $@

$(FLASHTOOL_TOOL): $(FLASHTOOL_CCOBJS)
	echo $(FLASHTOOL_CCOBJS)
	@echo host linking $@
	$(NOECHO)g++ $(HOST_LDFLAGS) -o $(FLASHTOOL_TOOL) $(FLASHTOOL_CCOBJS) -lpthread

HOST_GENERATED += $(FLASHTOOL_TOOL)

EXTRA_BUILDDEPS += $(FLASHTOOL_TOOL)

EXTRA_CLEANDEPS += host-tools-clean

.PHONY: host-tools-clean
host-tools-clean:
	rm -rf $(HOST_TOOLS_CCOBJS) $(HOST_TOOLS_DEPS) $(HOST_GENERATED)

include make/module.mk
