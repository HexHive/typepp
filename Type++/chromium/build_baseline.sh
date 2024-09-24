#!/bin/bash
cd "${HOME}"/LLVM-typepp || exit
docker build . --target chromium_baseline -t chromium_baseline
docker run --mount source=.,target=/home/nbadoux/LLVM-typepp,type=bind,consistency=cached --mount source=/tmp/.X11-unix,target=/tmp/.X11-unix,type=bind,consistency=cached --shm-size=64g --privileged  --name chromium_baseline_container -t chromium_baseline
docker commit chromium_baseline_container chromium_baseline_eval
docker rm chromium_baseline_container
docker image rm chromium_baseline
