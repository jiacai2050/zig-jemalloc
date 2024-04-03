#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

set -ex
export CC="zig cc"
(cd "${SCRIPT_DIR}/jemalloc" && ./autogen.sh && ./configure --disable-cxx && make)
