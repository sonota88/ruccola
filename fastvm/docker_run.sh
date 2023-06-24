#!/bin/bash

print_this_dir() {
  (
    cd "$(dirname "$0")"
    pwd
  )
}

. $(print_this_dir)/common.sh

docker run --rm -it \
  -v"$(pwd):/home/${USER}/work" \
  $IMAGE_FULL "$@"
