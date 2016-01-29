#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# This program displays information about the Fletch persistent process.
#
# It supports an option -k (or --kill) which will kill the process after
# displaying the information.
#
# This is a tool that's intended for people building the Fletch VM. If you find
# yourself using this on a regular basis, please get in touch with the authors
# and let us know why. If you're unsure about how to reach the authors, you're
# welcome to file an issue at https://github.com/dart-lang/fletch/issues/new.

# Using ~ instead of $HOME as this should match what the fletch command does
# (it will fall back to getpwuid_r if HOME isn't defined).
fletch_file=~/.fletch

if [ -f "$FLETCH_SOCKET_FILE" ]; then
  fletch_file="$FLETCH_SOCKET_FILE"
fi

for argument in "$@"; do
  case "$argument" in
    -k|--kill)
      kill=1
      ;;
    -*)
      echo Unknown option: "$argument" >&2
      has_bad_options=1
      ;;
    *)
      fletch_file="$argument"
      ;;
  esac
done

if [ $has_bad_options ]; then
  exit 1
fi

for socket in $(xargs < $fletch_file) ; do
  if [ -e "$socket" ] ; then
    for pid in $(lsof -t -- "$socket" ) ; do
      echo Persistent Fletch process $pid:
      ps -w -w -o args= -p $pid
      if [ $kill ]; then
        kill -TERM $pid
        : > $fletch_file
      fi
    done
  fi
done
