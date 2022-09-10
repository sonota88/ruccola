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

timestamp() {
  date "+%s.%N"
}

log_time() {
  local name="$1"; shift
  echo "${name} $(timestamp)" >> $LOGFILE
}

test_selfhost() {
  local name="$1"

  echo "compile ${name}" >&2
  {
    printf "\n"
    echo "# ==== compile ${name} ===="
  } >> $LOGFILE

  ../rclc ${name}.rcl > ${TEMP_DIR}/${name}_gen1.exe.txt

  log_time "${name}_beg"
  ./rclc  ${name}.rcl > ${TEMP_DIR}/${name}_gen2.exe.txt

  {
    echo "@beg ${name}"
    cat tmp/rclc.log
    echo "@end ${name}"
  } >> $LOGFILE
  log_time "${name}_end"

  local timestamp=$(date "+%Y%m%d_%H%M%S")

  diff_file=/tmp/rcl_test_selfhost_${timestamp}_${name}.diff

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
LOGFILE=${TEMP_DIR}/rclc_sub.log

mkdir -p tmp exe
build_all

{
  echo "---"
  printf "# "
  date "+%F %T"
} >> $LOGFILE

log_time "test_selfhost_beg"

test_selfhost rcl_lexer
test_selfhost rcl_parser
test_selfhost rcl_codegen

log_time "test_selfhost_end"

ruby test_selfhost_utils.rb print-times
