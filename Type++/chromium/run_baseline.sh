#!/bin/bash
cd "${HOME}"/LLVM-typepp || exit
docker run --mount source=.,target=/home/nbadoux/LLVM-typepp,type=bind,consistency=cached --mount source=/tmp/.X11-unix,target=/tmp/.X11-unix,type=bind,consistency=cached --shm-size=64g --privileged --name "chromium_baseline_eval_container" --env ENVIRONMENT_FOLDER=/home/nbadoux --user nbadoux -it chromium_baseline_eval /home/nbadoux/LLVM-typepp/Type++/chromium/eval/eval.sh ref
docker cp chromium_baseline_eval_container:/home/nbadoux/LLVM-typepp/Type++/chromium/eval/ref.json ./results/
