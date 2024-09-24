#!/bin/bash
# shellcheck  disable=SC1091

set -x
set -e

source "${ENVIRONMENT_FOLDER}/environment_patched.sh"
echo "$BUILD_DIR"
if [ -z "$BUILD_DIR" ]; then
  export BUILD_DIR=${BUILD_FOLDER}
fi
cd "${BUILD_DIR}/.."

rm -drf libcxx-build libcxxabi-build libunwind-build;

LIBC_FOLDER=${TEMP_FOLDER}"/libc/"
rm -drf "$LIBC_FOLDER"
mkdir -p "$LIBC_FOLDER"

export TYPEPLUS_LOG_PATH=${LIBC_FOLDER}"libunwind/"
export TARGET_TYPE_LIST_PATH=${TYPEPLUS_LOG_PATH}"/merged.txt"
mkdir -p "$TYPEPLUS_LOG_PATH"
touch "$TARGET_TYPE_LIST_PATH"

#order matters here
mkdir -p libunwind-build
cd libunwind-build
"${SRC_FOLDER}/libunwind_cmake.sh"
ninja clean
ninja
ninja install
cd ..
python3 "${TYPESAFETY_FOLDER}/script/merge_typecasting_related_type.py" "$TYPEPLUS_LOG_PATH" > "$TARGET_TYPE_LIST_PATH"

echo "$TYPEPLUS_LOG_PATH"
echo "$TARGET_TYPE_LIST_PATH"

export TYPEPLUS_LOG_PATH=${LIBC_FOLDER}"libc++abi/"
export TARGET_TYPE_LIST_PATH=${TYPEPLUS_LOG_PATH}"/merged.txt"
mkdir -p "$TYPEPLUS_LOG_PATH"
touch "$TARGET_TYPE_LIST_PATH"

cd "${BUILD_DIR}/.."
mkdir -p libcxxabi-build
cd libcxxabi-build
"${SRC_FOLDER}/libcxxabi_cmake.sh"
ninja
ninja install
cd ..
python3 "${TYPESAFETY_FOLDER}/script/merge_typecasting_related_type.py" "$TYPEPLUS_LOG_PATH" > "$TARGET_TYPE_LIST_PATH"

export TYPEPLUS_LOG_PATH=${LIBC_FOLDER}"libc++/"
export TARGET_TYPE_LIST_PATH=${TYPEPLUS_LOG_PATH}"/merged.txt"
mkdir -p "$TYPEPLUS_LOG_PATH"
touch "$TARGET_TYPE_LIST_PATH"

cd "${BUILD_DIR}/.."
mkdir -p libcxx-build
cd libcxx-build
"${SRC_FOLDER}/libcxx_cmake.sh"
ninja
ninja install
cd ..
python3 "${TYPESAFETY_FOLDER}/script/merge_typecasting_related_type.py" "$TYPEPLUS_LOG_PATH" > "$TARGET_TYPE_LIST_PATH"

set +x
