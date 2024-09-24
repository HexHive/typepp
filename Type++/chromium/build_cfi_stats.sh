#!/bin/bash
cd "${HOME}"/LLVM-typepp || exit
docker build . --target chromium_cfi_stats -t chromium_cfi_stats
docker run --mount source=.,target=/home/nbadoux/LLVM-typepp,type=bind,consistency=cached --mount source=/tmp/.X11-unix,target=/tmp/.X11-unix,type=bind,consistency=cached --shm-size=64g --privileged  --name chromium_cfi_stats_container -it chromium_cfi_stats
docker commit chromium_cfi_stats_container chromium_cfi_stats_eval
docker rm chromium_cfi_stats_container
docker image rm chromium_cfi_stats
