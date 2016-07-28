#!/bin/bash
# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Script to update the Dart binaries used in dartino.
#
# The version of these binaries should match the version of the Dart SDK that is
# referenced in the DEPS file as "dart_rev".
#
# We usually update these versions to the current version of the dev branch of
# Dart (https://github.com/dart-lang/sdk/tree/dev).  This script assumes that we
# use a commit on that branch!

if [ $# -eq 0 ] || [ $# -gt 3 ]
  then
    echo "Usage: update-dartino-binaries.sh VERSION [DOWNLOAD-PATH] [SDK-PATH]"
    echo "  DOWNLOAD-PATH and SDK-PATH default to the current directory."
    exit 1
fi

VERSION="$1"

TARGET_PATH="."
if [ ! -z "$2" ]
  then TARGET_PATH="$2"
fi

SDK_PATH="."
if [ ! -z "$3" ]
  then SDK_PATH="$3"
fi

if [ ! -e "$SDK_PATH/dartino.gyp" ]
  then
    echo "Directory '$SDK_PATH' does not look like a Dartino SDK!"
    exit 1
fi

if [ ! -e $TARGET_PATH ]
  then
    echo "Download directory '$TARGET_PATH' does not exist!"
    exit 1
fi


echo "Updating binaries in SDK $SDK_PATH to version $VERSION..."


DOWNLOAD_URL_BASE=https://storage.googleapis.com/dart-archive/channels/dev/release

pushd $TARGET_PATH

for p in windows-x64 macos-x64 linux-x64 linux-arm;
do
  SDK_NAME=dartsdk-$p-release
  if [ -e $SDK_NAME.zip ]; then
    rm $SDK_NAME.zip
  fi
  echo wget $DOWNLOAD_URL_BASE/$VERSION/sdk/$SDK_NAME.zip -q
  wget $DOWNLOAD_URL_BASE/$VERSION/sdk/$SDK_NAME.zip -q
  if [ -e $SDK_NAME ]; then
    rm -rf $SDK_NAME
  fi

  echo unzip -q $SDK_NAME.zip "dart-sdk/bin/dart*" -d $SDK_NAME
  unzip -q $SDK_NAME.zip "dart-sdk/bin/dart*" -d $SDK_NAME
done

cp dartsdk-linux-arm-release/dart-sdk/bin/dart $SDK_PATH/third_party/bin/linux/dart-arm
cp dartsdk-linux-x64-release/dart-sdk/bin/dart $SDK_PATH/third_party/bin/linux/dart
cp dartsdk-macos-x64-release/dart-sdk/bin/dart $SDK_PATH/third_party/bin/mac/dart
cp dartsdk-windows-x64-release/dart-sdk/bin/dart.exe $SDK_PATH/third_party/bin/win/dart.exe

popd


pushd $SDK_PATH

cd  third_party/bin/linux
upload_to_google_storage.py -b dartino-dependencies dart
cp dart.sha1 ../../../tools/testing/bin/linux/dart.sha1
upload_to_google_storage.py -b dartino-dependencies dart-arm
cp dart-arm.sha1 ../../../tools/testing/bin/linux/dart-arm.sha1
cd ../mac
upload_to_google_storage.py -b dartino-dependencies dart
cp dart.sha1 ../../../tools/testing/bin/mac/dart.sha1
cd ../win
upload_to_google_storage.py -b dartino-dependencies dart.exe
cp dart.exe.sha1 ../../../tools/testing/bin/win/dart.exe.sha1

popd
