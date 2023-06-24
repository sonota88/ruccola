#!/bin/bash

print_this_dir() {
  (
    cd "$(dirname "$0")"
    pwd
  )
}

. $(print_this_dir)/common.sh

RELEASE_FLAG=""

docker_build() {
  docker build \
    --build-arg USER=$USER \
    --build-arg GROUP=$(id -gn) \
    -t $IMAGE_FULL .
}

build() {
  ./docker_run.sh crystal build rcl_vm.cr \
    -o ./exe/rcl_vm $CR_OPTS
  status=$?
  if [ $status -ne 0 ]; then
    exit $status
  fi
}

cmd="$1"; shift
case $cmd in
  "docker-build" )
    docker_build
;; "build" )
    CR_OPTS="--static --error-trace" build
;; "build-release" )
    CR_OPTS="--static --release" build
;; * )
     echo "command not supported" >&2
     exit 1
esac
