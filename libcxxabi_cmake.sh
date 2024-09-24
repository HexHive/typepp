#!/usr/bin/env bash
set -e
cd "${BUILD_DIR}/../libcxxabi-build"

#-mllvm -create-derived-cast-type-list
#-DCMAKE_CXX_FLAGS="-O3 -v -fsanitize=typeplus -mllvm -apply-vtable-standard -mllvm -collect-profiling-data -mllvm -cast-obj-opt -mllvm -use-llvm-cfi-check -flto -fvisibility=hidden" \

CXXFLAGS=""
LDFLAGS=""
echo "${BUILD_DIR}"
cmake -GNinja -DLLVM_PATH="${LLVM_FOLDER}/llvm" \
 -DCMAKE_C_FLAGS="-O3" \
 -DCMAKE_CXX_FLAGS="-O3 -fsanitize=typeplus -mllvm -create-derived-cast-type-list -mllvm -create-unrelated-cast-type-list -mllvm -collect-profiling-data -flto -fvisibility=hidden -mllvm -old-class-list "\
 -DCMAKE_BUILD_TYPE=Release \
 -DCMAKE_CXX_COMPILER="${BUILD_DIR}/bin/clang++" \
 -DCMAKE_C_COMPILER="${BUILD_DIR}/bin/clang" \
 -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}" \
 -DLIBCXXABI_LIBCXX_PATH="${LLVM_FOLDER}/libcxx" \
 -DLIBCXXABI_LIBCXX_INCLUDES="${BUILD_DIR}/include/c++/v1" \
 -DLIBCXXABI_LIBUNWIND_PATH="${LLVM_FOLDER}/libunwind" \
 -DLIBCXXABI_LIBUNWIND_INCLUDES="${LLVM_FOLDER}/libunwind/include" \
 -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
 -DLIBCXXABI_ENABLE_SHARED=ON \
 -DCMAKE_POLICY_DEFAULT_CMP0116=OLD \
 "${LLVM_FOLDER}/libcxxabi"
