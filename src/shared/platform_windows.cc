// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#if defined(FLETCH_TARGET_OS_WIN)

#include "src/shared/platform.h"  // NOLINT

#include <windows.h>
#include <stdlib.h>
#include <malloc.h>

#include "src/shared/utils.h"

namespace fletch {

static uint64 time_launch;

void GetPathOfExecutable(char* path, size_t path_length) {
  HMODULE hModule = GetModuleHandle(NULL);
  if (hModule != NULL) {
    DWORD result = GetModuleFileName(hModule, path, path_length);
    if (result == 0 || result == path_length) {
      FATAL("GetModuleFileName failed");
    }
  } else {
    FATAL("GetModuleHandle for exe failed");
  }
}

void Platform::Setup() { time_launch = GetMicroseconds(); }

void Platform::TearDown() { }

uint64 Platform::GetMicroseconds() {
  SYSTEMTIME sys_time;
  FILETIME file_time;
  ULARGE_INTEGER milliseconds;

  // On Windows 8+ we could maybe also use GetSystemTimePreciseAsFileTime.
  GetSystemTime(&sys_time);
  SystemTimeToFileTime(&sys_time, &file_time);
  milliseconds.LowPart = file_time.dwLowDateTime;
  milliseconds.HighPart = file_time.dwHighDateTime;

  return milliseconds.QuadPart / 10;
}

uint64 Platform::GetProcessMicroseconds() {
  // Assume now is past time_launch.
  return GetMicroseconds() - time_launch;
}

int Platform::GetNumberOfHardwareThreads() {
  static int hardware_threads_cache_ = -1;
  if (hardware_threads_cache_ = -1) {
    SYSTEM_INFO info;

    GetSystemInfo(&info);

    hardware_threads_cache_ = info.dwNumberOfProcessors;
  }
  return hardware_threads_cache_;
}

// Load file at 'uri'.
List<uint8> Platform::LoadFile(const char* name) {
  // Open the file.
  HANDLE file = CreateFile(name, GENERIC_READ, FILE_SHARE_READ, NULL,
                           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

  // TODO(herhut): Use FormatMessage to provide proper error messages below.
  if (file == INVALID_HANDLE_VALUE) {
    Print::Error("Cannot open file '%s' for reading.\n%d.\n", name,
                 GetLastError());
    return List<uint8>();
  }

  // Determine the size of the file.
  LARGE_INTEGER size;
  if (!GetFileSizeEx(file, &size)) {
    Print::Error("Cannot get file size for file '%s'.\n%d.\n", name,
                 GetLastError());
    CloseHandle(file);
    return List<uint8>();
  }

  if (size.HighPart != 0) {
    Print::Error("File '%s' too big (%l bytes) to read..\n", name,
                 size.QuadPart);
    CloseHandle(file);
    return List<uint8>();
  }

  // Read in the entire file.
  uint8* buffer = static_cast<uint8*>(malloc(size.LowPart));
  if (buffer == NULL) {
    Print::Error("Cannot allocate %d bytes for file '%s'.\n", size.LowPart,
                 name);
    CloseHandle(file);
    return List<uint8>();
  }

  DWORD read;
  bool result = ReadFile(file, buffer, size.LowPart, &read, NULL);
  if (!result || read != size.LowPart) {
    Print::Error("Unable to read entire file '%s'.\n%s.\n", name,
                 GetLastError());
    return List<uint8>();
  }
  return List<uint8>(buffer, read);
}

bool Platform::StoreFile(const char* uri, List<uint8> bytes) {
  // Open the file.
  // TODO(herhut): Actually handle Uris.
  HANDLE file = CreateFile(uri, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                           FILE_ATTRIBUTE_NORMAL, NULL);

  // TODO(herhut): Use FormatMessage to provide proper error messages below.
  if (file == INVALID_HANDLE_VALUE) {
    Print::Error("Cannot open file '%s' for writing.\n%d.\n", uri,
                 GetLastError());
    return false;
  }

  DWORD written;
  bool result = WriteFile(file, bytes.data(), bytes.length(), &written, NULL);
  CloseHandle(file);
  if (!result || written != bytes.length()) {
    Print::Error("Unable to write entire file '%s'.\n%s.\n", uri,
                 GetLastError());
    return false;
  }

  return true;
}

bool Platform::WriteText(const char* uri, const char* text, bool append) {
  // Open the file.
  // TODO(herhut): Actually handle Uris.
  HANDLE file = CreateFile(uri, append ? FILE_APPEND_DATA : GENERIC_WRITE, 0,
                           NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);

  // TODO(herhut): Use FormatMessage to provide proper error messages below.
  if (file == INVALID_HANDLE_VALUE) {
    Print::Error("Cannot open file '%s' for writing.\n%d.\n", uri,
                 GetLastError());
    return false;
  }

  DWORD written;
  int length = lstrlen(text);
  bool result = WriteFile(file, text, length, &written, NULL);
  CloseHandle(file);
  if (!result || written != length) {
    Print::Error("Unable to write text to file '%s'.\n%s.\n", uri,
                 GetLastError());
    return false;
  }

  return true;
}

int Platform::GetLocalTimeZoneOffset() {
  TIME_ZONE_INFORMATION info;
  DWORD result = GetTimeZoneInformation(&info);
  LONG bias = info.Bias;
  if (result == TIME_ZONE_ID_STANDARD) {
    // Add the standard time bias.
    bias += info.StandardBias;
  } else if (result == TIME_ZONE_ID_DAYLIGHT) {
    // Add the daylight time bias.
    bias += info.DaylightBias;
  }
  // Even if the offset was 24 hours it would still easily fit into 32 bits.
  // Note that Windows and Dart disagree on the sign.
  return static_cast<int>(-bias);
}

const char* Platform::GetTimeZoneName(int64_t seconds_since_epoch) {
  // TODO(herhut): Not sure how to compute this without implementing it
  //               explicitly. For now, return the name at this point in time.
  TIME_ZONE_INFORMATION info;
  static char name[64];
  size_t converted;

  DWORD result = GetTimeZoneInformation(&info);
  wcstombs_s(
      &converted, name, 64,
      result == TIME_ZONE_ID_DAYLIGHT ? info.DaylightName : info.StandardName,
      _TRUNCATE);
  return name;
}

int Platform::GetTimeZoneOffset(int64_t seconds_since_epoch) {
  // TODO(herhut): There is no API in Windows for this it seems.
  UNIMPLEMENTED();
  return 0;
}

void Platform::Exit(int exit_code) { exit(exit_code); }

void Platform::ScheduleAbort() {
  static bool failed = false;
  if (!failed) atexit(abort);
  failed = true;
}

void Platform::ImmediateAbort() { abort(); }

int Platform::GetPid() { return static_cast<int>(GetCurrentProcessId()); }

VirtualMemory::VirtualMemory(int size) : size_(size) { UNIMPLEMENTED(); }

VirtualMemory::~VirtualMemory() { UNIMPLEMENTED(); }

bool VirtualMemory::IsReserved() const {
  UNIMPLEMENTED();
  return false;
}

bool VirtualMemory::Commit(uword address, int size, bool executable) {
  UNIMPLEMENTED();
  return false;
}

bool VirtualMemory::Uncommit(uword address, int size) {
  UNIMPLEMENTED();
  return false;
}

}  // namespace fletch

#endif  // defined(FLETCH_TARGET_OS_WIN)
