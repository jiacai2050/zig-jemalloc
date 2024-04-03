#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

set -ex
export CC="zig cc"

(cd "${SCRIPT_DIR}/jemalloc" && ./autogen.sh && ./configure --disable-cxx --with-jemalloc-prefix="je_" && make -j8)

cat "${SCRIPT_DIR}/jemalloc/include/jemalloc/jemalloc.h"
