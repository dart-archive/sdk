#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# This program runs the Dartino VM in a virtual terminal controlled by the
# program "screen". It then attaches to the VM using the given command-line
# arguments. Normal usage would be something like:
#
#  ./tools/spawn_vm_and_attach.sh out/DebugIA32Clang/dartino in session SESSION_NAME
#
# This is a tool that's intended for people building the Dartino VM. If you find
# yourself using this to run Dartino on a regular basis, please get in touch
# with the authors and let us know why. If you're unsure about how to reach the
# authors, you're welcome to file an issue at
# https://github.com/dartino/sdk/issues/new.

dartino="${1}"
shift
if [ ! -x "${dartino}" ]; then
  echo 1>&2 Usage: "$0" PATH_TO_DARTINO_EXECUTABLE
  exit 1
fi

# Make all errors fatal
set -e

# Create a FIFO file (aka named pipe)
fifo=$(mktemp -u -t fifo)
mkfifo "${fifo}"

# Launch the Dartino VM in a detached screen session, and duplicate its output
# to the FIFO (using script)
screen -L -d -m script -t 0 -q -a "${fifo}" "${dartino}-vm"

# Wait for the first line of output from the VM
tcp_socket=$(head -1 "${fifo}" | sed 's/^Waiting for compiler on //')

# We're done with the FIFO
rm "${fifo}"

# Attach to the VM
exec "${dartino}" attach tcp_socket "${tcp_socket}" "$@"
