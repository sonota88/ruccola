#!/bin/bash

set -o nounset

print_this_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

build_all() {
  rake build-all
  status=$?

  if [ $status -ne 0 ]; then
    exit $status
  fi
}

test_selfhost() {
  local name="$1"

  echo "compile ${name}:"

  ../rclc ${name}.rcl > ${TEMP_DIR}/${name}_gen1.exe.txt
  ./rclc  ${name}.rcl > ${TEMP_DIR}/${name}_gen2.exe.txt

  local timestamp=$(date "+%Y%m%d_%H%M%S")

  diff_file=/tmp/pric_test_selfhost_${timestamp}_${name}.diff

  diff -u \
    ${TEMP_DIR}/${name}_gen1.exe.txt \
    ${TEMP_DIR}/${name}_gen2.exe.txt \
    > $diff_file
  local status=$?

  if [ $status -ne 0 ]; then
    echo "Diff exists." >&2
    echo "See ${diff_file}" >&2
    exit $status
  fi
}

__DIR__="$(print_this_dir)"
TEMP_DIR="${__DIR__}/tmp"

mkdir -p tmp exe
build_all

test_selfhost lexer
test_selfhost parser
test_selfhost codegen
