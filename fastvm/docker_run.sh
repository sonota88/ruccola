#!/bin/bash

docker run --rm -it \
  -v"$(pwd):/home/${USER}/work" \
  ruccola-fast-vm:2 "$@"
