#!/usr/bin/env bash

set -xe
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TMP_DIR="${SCRIPT_DIR}/../zig-cache"

[ -d "${TMP_DIR}" ] || mkdir "${TMP_DIR}"

cd ${TMP_DIR} || exit 1

[ -f jemalloc.zip ] || curl -o "${TMP_DIR}/jemalloc.zip" \
 https://codeload.github.com/jemalloc/jemalloc/zip/refs/tags/5.3.0

unzip "${TMP_DIR}/jemalloc.zip"

# Remove old files
rm -rf "${SCRIPT_DIR}/jemalloc"
mv jemalloc-5.3.0 "${SCRIPT_DIR}/jemalloc"
# (cd jemalloc-5.3.0 && ./autogen.sh && ./configure)
