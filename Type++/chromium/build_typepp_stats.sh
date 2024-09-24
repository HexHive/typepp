#!/bin/bash
cd "${HOME}"/LLVM-typepp || exit
docker build . --target chromium_typepp_profiling -t chromium_typepp_profiling
docker run --mount source=.,target=/home/nbadoux/LLVM-typepp,type=bind,consistency=cached --mount source=/tmp/.X11-unix,target=/tmp/.X11-unix,type=bind,consistency=cached --shm-size=64g --privileged  --name chromium_typepp_profiling_container -it chromium_typepp_profiling
docker commit chromium_typepp_profiling_container chromium_typepp_profiling_eval
docker rm chromium_typepp_profiling_container
docker image rm chromium_typepp_profiling
