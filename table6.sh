#!/bin/bash
chmod 777 -R ${HOME}/LLVM-typepp/Type++/chromium/eval
${HOME}/LLVM-typepp/Type++/chromium/build_baseline.sh
${HOME}/LLVM-typepp/Type++/chromium/build_cfi.sh
${HOME}/LLVM-typepp/Type++/chromium/build_typepp.sh
${HOME}/LLVM-typepp/Type++/chromium/build_cfi_stats.sh
${HOME}/LLVM-typepp/Type++/chromium/build_typepp_stats.sh

cd ${HOME}/LLVM-typepp
chmod 777 -R ${HOME}/LLVM-typepp/Type++/chromium/eval
mkdir -p results

${HOME}/LLVM-typepp/Type++/chromium/run_baseline.sh
${HOME}/LLVM-typepp/Type++/chromium/run_cfi.sh
${HOME}/LLVM-typepp/Type++/chromium/run_typepp.sh
${HOME}/LLVM-typepp/Type++/chromium/run_cfi_stats.sh
${HOME}/LLVM-typepp/Type++/chromium/run_typepp_stats.sh

export RESULT_FOLDER=./results
${HOME}/LLVM-typepp/Type++/chromium/gettable.py
