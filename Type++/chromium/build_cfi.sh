#!/bin/bash
cd "${HOME}"/LLVM-typepp || exit
docker build . --target chromium_cfi -t chromium_cfi
docker run --mount source=.,target=/home/nbadoux/LLVM-typepp,type=bind,consistency=cached --mount source=/tmp/.X11-unix,target=/tmp/.X11-unix,type=bind,consistency=cached --shm-size=64g --privileged  --name chromium_cfi_container -t chromium_cfi
docker commit chromium_cfi_container chromium_cfi_eval
docker rm chromium_cfi_container
docker image rm chromium_cfi
