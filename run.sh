#!/bin/bash

set -o errexit
set -o nounset

print_this_dir() {
  (
    cd "$(dirname $0)"
    pwd
  )
}

__DIR__="$(print_this_dir)"
TEMP_DIR=${__DIR__}/tmp/

mkdir -p $TEMP_DIR

file="$1"
# bname=$(basename $file .vg.txt)
bname=run

src_temp=tmp/${bname}.rcl.rb

ruby ${__DIR__}/preproc.rb $file > $src_temp

tokensfile=${TEMP_DIR}/${bname}.vgtokens.txt
treefile=${TEMP_DIR}/${bname}.vgt.json
asmfile=${TEMP_DIR}/${bname}.vga.txt
exefile=${TEMP_DIR}/${bname}.vge.txt

ruby rcl_lexer.rb $src_temp > $tokensfile
ruby rcl_parser.rb $tokensfile > $treefile
ruby rcl_codegen.rb $treefile > $asmfile
ruby rcl_asm.rb $asmfile > $exefile
ruby rcl_vm.rb $exefile
