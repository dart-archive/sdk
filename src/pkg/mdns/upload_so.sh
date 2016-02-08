# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# You need to be logged in using gsutil.py to get the correct credentials to
# upload
#
#  $ gsutil.py config
#
# Using 'gsutil config' (without .py) or 'gclient auth login' probably won't
# work.

upload_to_google_storage.py -b dartino-dependencies \
    pkg/mdns/lib/native/libmdns_extension_lib.so
