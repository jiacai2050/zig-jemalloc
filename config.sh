#!/usr/bin/env bash

export CC="zig cc"
export CXX="zig c++"
jemalloc_dir="$1"

set -xe
cd "${jemalloc_dir}"
./autogen.sh
./configure --disable-cxx --with-jemalloc-prefix="je_"
make include/jemalloc/internal/private_namespace_jet.gen.h
make include/jemalloc/internal/private_namespace.h
