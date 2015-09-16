#!/bin/bash

# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# This file compiles the github mock data files in to a single Dart file with a
# hash-map of the raw file data and generates a snapshot for running the mock
# server with this data.

set -ue

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FLETCH_DIR="$(cd "$DIR/../.." && pwd)"
DATA_DIR="$DIR/lib/src/github_mock_data"
DATA_FILE="$DIR/lib/src/github_mock.data"
IDL_FILE="$DIR/lib/src/github_mock.idl"
MOCK_FILE="$DIR/bin/github_mock_service.dart"
SNAPSHOT_FILE="$DIR/github_mock_service.snapshot"

DART="$FLETCH_DIR/out/ReleaseIA32/dart"
FLETCH="$FLETCH_DIR/out/ReleaseIA32/fletch"
SERVICEC="$DART $FLETCH_DIR/tools/servicec/bin/servicec.dart"

SERVICE_GEN_DIR="$FLETCH_DIR/package/service"

if [[ $# -eq 0 ]] || [[ "$1" == "data" ]]; then
    cd $DATA_DIR
    echo "const Map<String, List<int>> resources = const <String, List<int>> {"\
	 > $DATA_FILE
    for f in `find . -type f -name *\\\\.data`; do
	key=`echo $f | cut -b 3- | cut -d . -f 1`
	echo "'$key': const <int>[" >> $DATA_FILE
	od -A n -t d1 $f |\
            sed 's/\([^ ]\) /\1,/g' |\
            sed 's/\([^ ]\)$/\1,/' >> $DATA_FILE
	echo "]," >> $DATA_FILE
    done
    echo "};" >> $DATA_FILE
fi

if [[ $# -eq 0 ]] || [[ "$1" == "service" ]]; then
    # TODO(zerny): This must output service files *in the existing directory*.
    # Find another way of supporting multiple services!
    mkdir -p "$SERVICE_GEN_DIR"
    $SERVICEC --out "$SERVICE_GEN_DIR" "$IDL_FILE"
fi

if [[ $# -eq 0 ]] || [[ "$1" == "snapshot" ]]; then
    cd $FLETCH_DIR
    ninja -C out/ReleaseIA32
    ./tools/persistent_process_info.sh --kill
    $FLETCH compile-and-run -o "$SNAPSHOT_FILE" "$MOCK_FILE"
fi
