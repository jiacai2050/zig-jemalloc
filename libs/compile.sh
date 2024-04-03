#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

export CC="zig cc"

set -ex

if [ ! -f "$SCRIPT_DIR/jemalloc/lib/libjemalloc.a" ];then
  cd "${SCRIPT_DIR}/jemalloc"
  bash ./autogen.sh
  ./configure --disable-cxx --with-jemalloc-prefix="je_"
  make -j8
fi
