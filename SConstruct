# Copyright (c) 2013, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# SCons build description file.
# See http://scons.org/.

import os
import platform
from time import asctime
from os.path import abspath, dirname, join


# Make sure that we're running at least Python 2.4 and SCons 1.0
# and compute the root directory.
EnsurePythonVersion(2, 4)
EnsureSConsVersion(1, 0)
Decider("MD5-timestamp")
root = dirname(File("SConstruct").rfile().abspath)

# Compute helper script locations.
cpplint = File(join("third_party", "cpplint", "cpplint.py")).rfile()

# Try to guess the host operating system.
def GuessOS():
  id = platform.system()
  if id == "Linux":
    return "linux"
  elif id == "Darwin":
    return "macos"
  elif id == "Windows" or id == "Microsoft":
    # On Windows Vista platform.system() can return "Microsoft" with some
    # versions of Python, see http://bugs.python.org/issue1082 for details.
    return "win32"
  else:
    return "unknown"

# Define the SCons command line variables.
variables = Variables()
variables.Add(EnumVariable("os", "Set target operating system",
                           GuessOS(),
                           allowed_values=("linux", "macos", "win32")))
variables.Add(BoolVariable("asan", "Compile with ASan support",
                           False))
variables.Add(BoolVariable("clang", "Compile with the Clang compiler", False))

# Define the common compilation environment.
common = Environment(
  variables    = variables,
  DIALECTFLAGS = ["-ansi"],
  WARNINGFLAGS = ["-Wall", "-W", "-Werror", "-Wno-unused-parameter", "-Wno-format",
                  "-Wno-non-virtual-dtor"],
  CXXFLAGS     = ["$DIALECTFLAGS", "$WARNINGFLAGS", "-fno-rtti", "-fno-exceptions",
                  "-fdata-sections", "-ffunction-sections", "-std=c++11"],
  CCFLAGS      = ["$MODEL"],
  LINKFLAGS    = ["$MODEL"],
  ASPPFLAGS    = ["$MODEL"],
  CPPPATH      = [root],
  ENV          = {"PATH": os.environ["PATH"]})

# Compile using 'scons asan=true' to get ASan-enabled binaries.
if common["asan"]:
  sanitize = ["-fsanitize=address"]
  common.Append(CXXFLAGS=sanitize, LINKFLAGS=sanitize)
  common.Append(CXXFLAGS=["-g3"])  # Preserve symbols.

if common["clang"]:
  common.Replace(CXX="clang++")
  common.Replace(CC="clang")

# Add support for threading and dynamic symbol lookup on Linux and Mac.
if common["os"] == "linux" or common["os"] == "macos":
  common.Append(LIBS=["tcmalloc_minimal", "pthread", "dl"],
                LINKFLAGS=["-rdynamic"])

# Strip dead stuff out at link time. Don't use the linker to strip on
# Mac. That strips out too much. Use 'strip -x' on the command line
# instead to leave global symbols alone.
if common["os"] == "linux":
  common.Append(LINKFLAGS=["-Wl,--gc-sections"])

# Load the file lists.
files = {
  'compiler' : SConscript(join("src", "compiler", "SOURCE")),
  'vm' : SConscript(join("src", "vm", "SOURCE")),
  'shared' : SConscript(join("src", "shared", "SOURCE")),
  'echo_service_api_test' : SConscript(join("tests",
                                            "service_tests",
                                            "echo",
                                            "SOURCE")),
  'double_conversion' : SConscript(join("third_party",
                                        "double-conversion",
                                        "src",
                                        "SConscript"))
}

# Setup builder for running 'lint' on the source files.
common["BUILDERS"]["Lint"] = \
    Builder(action=str(cpplint) + " $SOURCES > $TARGET")

# Use the common environment for linting.
def ScheduleLint(component):
  return SConscript(
      join("src", component, "SConscript.lint"),
      variant_dir=join("build", component),
      exports="common files",
      duplicate=0)

lint = [ ScheduleLint("compiler"), ScheduleLint("vm"), ScheduleLint("shared") ]

# Contexts are used to communicate settings to the subparts of the
# build process. We use a special context for each variant.
class VariantContext(object):
  def __init__(self, name, common, *modifiers):
    self.environment = common.Clone()
    for m in modifiers: m(self.environment)
    self.name = name
    self.directory = self.environment["os"] + "_" + name
    # TODO(kasperl): Generalize this to work for ARM too.
    if self.environment["MODEL"] == ["-m32"]: arch = "x86"
    else: arch = "x64"
    os = self.environment["os"]
    self.configuration = "arch:" + arch + ",os:" + os
    self.files = files
    link_path = join("third_party/libs", os, arch)
    self.environment.Append(LINKFLAGS=["-L" + link_path])

# Helpers to compute the command line, source, and output for C++ unit tests.
def ComputeTestCommand(env, source):
  return str(source[0])

def ComputeTestSource(env, source):
  return source

def ComputeTestOutput(env, source):
  return [ str(source[0]) + ".pass" ]

# Run the test, but only produce the output if the test succeeds.
# This way, the test will be automatically rerun if it fails.
def RunTests(env, target, source):
  command = ComputeTestCommand(env, source)
  result = os.system(command)
  if result == 0:
    file = open(str(target[0]), "w")
    file.write("Test passed on " + asctime() + "\n")
    file.close()
  return result

# Produce a one line output that shows that a test is being run.
def ShowTestsRun(target, source, env):
  command = ComputeTestCommand(env, source)
  print "Running tests: " + command + " > " + str(target[0])

def DefineVariantComponent(context, component):
  return SConscript(join("src", component, "SConscript"),
      variant_dir=join("build", component, context.directory),
      exports="context",
      duplicate=0)

def DefineVariant(name, *modifiers):
  context = VariantContext(name, common, *modifiers)
  shared = DefineVariantComponent(context, 'shared')
  context.shared = shared

  double_conversion_objects = SConscript(
      join("third_party", "double-conversion", "SConscript"),
      variant_dir=join("build", "double_conversion", context.directory),
      exports="context",
      duplicate=0);
  context.double_conversion_objects = double_conversion_objects

  compiler = DefineVariantComponent(context, 'compiler')
  vm = DefineVariantComponent(context, 'vm')

  vm_library_name = "build/%s/lib/fletch" % (context.directory)
  vm_static_library = context.environment.StaticLibrary(
    vm_library_name,
    vm["vm_library_objects"])

  echo_service_tests = SConscript(
      join("tests", "service_tests", "echo", "SConscript"),
      variant_dir=join("build", "service_tests", "echo", context.directory),
      exports="context",
      duplicate=0);

  echo_service_test = {
       "name": "echo_service_test",
       "objects": echo_service_tests["objects"] + [vm_static_library],
       "env": "default"
     }

  program_definitions = compiler["programs"]
  program_definitions += vm["programs"]
  program_definitions += shared["programs"]
  program_definitions += [ echo_service_test ]

  objc_env = context.environment.Clone()
  objc_env.Append(LINKFLAGS=["-framework", "Foundation", "-Wl,-no_pie"])

  if common["os"] == "macos":
    objc_echo_service_test = { "name": "objc_echo_service_test",
                               "objects": echo_service_tests["objc_objects"] +
                                          [vm_static_library],
                               "env": "objc" }
    program_definitions += [ objc_echo_service_test ]

  programs = []

  for program in program_definitions:
    name = "build/%s/%s" % (context.directory, program["name"])
    env = context.environment
    if program["env"] == "objc":
        env = objc_env
    elif program["env"] != "default":
        raise "unknown environment"
    programs.append(env.Program(name, program["objects"]))

  test_targets = compiler["tests"] + vm["tests"] + shared["tests"]
  # For now, we always run the C++ tests. We could consider adding a
  # flag for explicitly enabling it instead, if it starts taking too
  # long to run them.
  tests = [ common.Command(ComputeTestOutput(common, test),
                           ComputeTestSource(common, test),
                           Action(RunTests, ShowTestsRun))
            for test in test_targets ]

  # The tests needs to be able to invoke fletchc.
  for test in tests:
    context.environment.Depends(test, programs)

  return Alias(name, programs + lint + tests)

# Modifiers on the environment.
def Set32(env):
  env.Append(MODEL=["-m32"], CPPDEFINES=["FLETCH32"])

def Set64(env):
  env.Append(MODEL=["-m64"], CPPDEFINES=["FLETCH64"])

def SetDebug(env):
  env.Append(CCFLAGS=["-g", "-O0"], CPPDEFINES=["DEBUG"], ASPPFLAGS=["-g"])

def SetRelease(env):
  env.Append(CCFLAGS=["-O3", "-fomit-frame-pointer"], CPPDEFINES=["NDEBUG"])

# Define the variants and build them all by default.
debug_x86 = DefineVariant("debug_x86", Set32, SetDebug)
debug_x64 = DefineVariant("debug_x64", Set64, SetDebug)
release_x86 = DefineVariant("release_x86", Set32, SetRelease)
release_x64 = DefineVariant("release_x64", Set64, SetRelease)

Default([release_x86, release_x64, debug_x86, debug_x64])
