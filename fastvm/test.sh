#!/bin/bash

print_this_dir() {
  (
    cd "$(dirname "$0")"
    pwd
  )
}

__DIR__="$(print_this_dir)"
TEMP_DIR=${__DIR__}/tmp
TEMP_EXE_FILE=${TEMP_DIR}/test.exe.txt
EXE_DIR=${__DIR__}/exe

VM_RB=../rclvm
VM_CR=${EXE_DIR}/rcl_vm

TEMP_EXP_FILE=${TEMP_DIR}/test_exp.txt
TEMP_ACT_FILE=${TEMP_DIR}/test_act.txt

echo_head() {
  local msg="$1"; shift

  echo "==== $msg ===="
}

assert_output() {
  local name="$1"; shift

  echo_head "output: $name"

  DUMP_FOR_TEST=0 $VM_RB $TEMP_EXE_FILE > $TEMP_EXP_FILE
  DUMP_FOR_TEST=0 $VM_CR $TEMP_EXE_FILE > $TEMP_ACT_FILE

  diff -u \
    $TEMP_EXP_FILE \
    $TEMP_ACT_FILE
}

assert_dump() {
  local name="$1"; shift

  echo_head "$name"

  DUMP_FOR_TEST=1 $VM_RB $TEMP_EXE_FILE > $TEMP_EXP_FILE
  DUMP_FOR_TEST=1 $VM_CR $TEMP_EXE_FILE > $TEMP_ACT_FILE

  diff -u \
    $TEMP_EXP_FILE \
    $TEMP_ACT_FILE
}

test_write() {
  cat <<__EXE > $TEMP_EXE_FILE
["write", 65, 1]
["write", 66, 1]
["write", 67, 1]
["write", 10, 1]
["write", 68, 1]
["exit", 0]
__EXE

  assert_output "write"
}

test_read() {
  local name="read"
  local stdin_file="${TEMP_DIR}/stdin"

  cat <<__EOF > $TEMP_EXE_FILE
["read", "reg_a"]
["write", "reg_a", 1]
["exit", 0]
__EOF

  echo_head "output: $name"

  echo "A" > $stdin_file

  STDIN="$stdin_file" $VM_RB $TEMP_EXE_FILE > z_exp.txt
  STDIN="$stdin_file" $VM_CR $TEMP_EXE_FILE > z_act.txt

  diff -u z_exp.txt z_act.txt
}

test_cp() {
  cat <<__EXE > $TEMP_EXE_FILE
["cp", 1, "reg_a"]
["exit", 0]
__EXE

  assert_dump "add_ab"
}

test_add_ab() {
  cat <<__EXE > $TEMP_EXE_FILE
["cp", 65, "reg_a"]
["cp", 2, "reg_b"]
["add_ab"]
["write", "reg_a", 1]
["exit", 0]
__EXE

  assert_dump "add_ab"
}

test_lea() {
  cat <<__EXE > $TEMP_EXE_FILE
["lea", "reg_a", "ind:bp:0:0"]
["exit", 0]
__EXE

  assert_dump "lea"
}

test_sub_sp() {
  cat <<__EXE > $TEMP_EXE_FILE
["sub_sp", 2]
["exit", 0]
__EXE

  assert_dump "sub_sp"
}

test_compare() {
  cat <<__EXE > $TEMP_EXE_FILE
["cp", 0, "reg_a"]
["cp", 1, "reg_b"]
["compare"]
["exit", 0]
__EXE

  assert_dump "compare"
}

test_jump() {
  cat <<__EXE > $TEMP_EXE_FILE
["jump", 2]
["write", 65, 1]
["write", 66, 1]
["exit", 0]
__EXE

  assert_output "jump"
}

test_jump_eq() {
  cat <<__EXE > $TEMP_EXE_FILE
["cp", 1, "reg_a"]
["cp", 1, "reg_b"]
["compare"]
["jump_eq", 6]
["write", 65, 1]
["exit", 0]
["write", 66, 1]
["exit", 0]
__EXE

  assert_dump "jump_eq"
}

test_jump_g() {
  cat <<__EXE > $TEMP_EXE_FILE
["cp", 1, "reg_a"]
["cp", 2, "reg_b"]
["compare"]
["jump_g", 6]
["write", 65, 1]
["exit", 0]
["write", 66, 1]
["exit", 0]
__EXE

  assert_dump "jump_g"
}

cd "$__DIR__"

mkdir -p "$EXE_DIR"

./run.sh build

test_cp
test_add_ab
test_lea
test_write
test_read
test_sub_sp
test_compare
test_jump
test_jump_eq
test_jump_g
