#!/bin/bash
cd "${HOME}"/LLVM-typepp || exit
docker build . --target chromium_typepp -t chromium_typepp
docker run --mount source=.,target=/home/nbadoux/LLVM-typepp,type=bind,consistency=cached --mount source=/tmp/.X11-unix,target=/tmp/.X11-unix,type=bind,consistency=cached --shm-size=64g --privileged  --name chromium_typepp_container -it chromium_typepp 
docker commit chromium_typepp_container chromium_typepp_eval
docker rm chromium_typepp_container
docker image rm chromium_typepp
