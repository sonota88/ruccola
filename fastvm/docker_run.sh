#!/bin/bash

docker run --rm -it \
  -v"$(pwd):/home/${USER}/work" \
  pric-fast-vm:0.0.1 "$@"
