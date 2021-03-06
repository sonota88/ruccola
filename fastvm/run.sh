#!/bin/bash

RELEASE_FLAG=""

docker_build() {
  docker build \
    --build-arg USER=$USER \
    --build-arg GROUP=$(id -gn) \
    -t pric-fast-vm:0.0.1 .
}

build() {
  ./docker_run.sh crystal build rclvm.cr \
    -o ./exe/rclvm $CR_OPTS
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
    CR_OPTS="--error-trace" build
;; "build-release" )
    CR_OPTS="--release" build
;; * )
     echo "command not supported" >&2
     exit 1
esac
