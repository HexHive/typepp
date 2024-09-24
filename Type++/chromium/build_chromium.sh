#!/bin/bash
set -e
set -x

if [[ -z "${ENVIRONMENT_FOLDER}" ]]; then
  echo "ENVIRONMENT_FOLDER not set, leave"
  exit 1
fi
# set the environment properly, find better folder for the original script
if [ ! -f "${ENVIRONMENT_FOLDER}"/environment_patched.sh ]
then
    echo "environment_patched.sh doest not exist. Aborting..."
    exit 255
fi
# shellcheck source=../environment_patched.sh
source "${ENVIRONMENT_FOLDER}"/environment_patched.sh 
export TYPEPLUS_LOG_PATH="/tmp/chromium"
export TARGET_TYPE_LIST_PATH=${TYPEPLUS_LOG_PATH}"/merged.txt"

export LLVM_BUILD_DIR=${BUILD_FOLDER}
export PATH="$PATH:$HOME/depot_tools"

# DO ./fetch_repos in TYPESAFETY_FOLDER/LLVM, to get libunwind, etc

sudo chmod -R 777 ${CCACHE_DIR}


export IS_DEBUG=false
export CLASS_INSTRUMENTATION=false
export FOR_PROGRAM=""

export VERSION=""
export CXXFLAGS+=" -flto -fvisibility=hidden "
export LDFLAGS+="  -flto -fvisibility=hidden "
if [[ $1 == ref* ]] ; then
    export VERSION=ref
    export CCACHE_RECACHE=true
    cd /home/nbadoux/chromium
    git checkout typepp --
    git reset --hard typepp 
fi
if [[ $1 == cfi* ]] ; then
    export VERSION=cfi
    export CXXFLAGS+="\
    -fno-sanitize-trap=cfi-derived-cast,cfi-unrelated-cast \
    -fsanitize-recover=cfi-derived-cast,cfi-unrelated-cast \
    -fsanitize=cfi-derived-cast,cfi-unrelated-cast "
    export LDFLAGS+=" \
    -fno-sanitize-trap=cfi-derived-cast,cfi-unrelated-cast \
    -fsanitize-recover=cfi-derived-cast,cfi-unrelated-cast \
    -fsanitize=cfi-derived-cast,cfi-unrelated-cast "
    cd /home/nbadoux/chromium
    if [[ $1 == cfi_stats* ]] ; then
        export VERSION=cfi_stats
        export CXXFLAGS+=" -fsanitize=typeplus -mllvm -collect-profiling-data \
                           -mllvm -wrong-polymorphism \
               -mllvm -missing-checks "
        export LDFLAGS+="  -fsanitize=typeplus -mllvm -collect-profiling-data -mllvm -missing-checks "
    fi
    git checkout typepp --
    git reset --hard typepp 
fi
if [[ $# -eq 0 || $1 == typepp* ]] ; then
    cd /home/nbadoux/chromium
    #rm -drf $TYPEPLUS_LOG_PATH
    mkdir -p $TYPEPLUS_LOG_PATH
    touch $TARGET_TYPE_LIST_PATH
    export VERSION=typepp
    export CLASS_INSTRUMENTATION=true
    if [[ $1 == typepp_collect* ]] ; then
        export VERSION=typepp_collect
        export CXXFLAGS+=" -fsanitize=typeplus "
        export CXXFLAGS+=" -mllvm -create-derived-cast-type-list \
                           -mllvm -create-unrelated-cast-type-list "
        export CCACHE_RECACHE=true
        export CXXFLAGS+=" -mllvm -collect-profiling-data "
        #export CXXFLAGS+=" -mllvm -collect-profiling-data-all "
        git checkout typepp --
        git reset --hard typepp 
    else
        export CXXFLAGS+=" -fsanitize=typeplus "
        export FOR_PROGRAM="-for-program"
        git checkout typepp-partial-changes --
        git reset --hard typepp-partial-changes
        export CXXFLAGS+=" -mllvm -cast-obj-opt  \
                           -mllvm -apply-vtable-standard \
                           -mllvm -poly-classes \
                           -mllvm -wrong-polymorphism \
                           -mllvm -missing-checks \
                           -mllvm -no-check-unsupported-class \
                           -mllvm -old-class-list "
    fi
    if [[ $1 == typepp_warning* ]] ; then
        export VERSION=typepp_warning
        export CXXFLAGS+=" -mllvm -collect-profiling-data "
    fi
    if [[ $1 == typepp_checking* ]] ; then
        export CXXFLAGS+=" -mllvm -check-unrelated-casting \
                           -mllvm -check-base-to-derived-casting "
        export VERSION=typepp_checking
        if [[ $1 == typepp_checking_profiling* ]] ; then
            export CXXFLAGS+=" -mllvm -collect-profiling-data "
            export VERSION=typepp_checking_profiling
        fi
    fi
fi
if [[ $1 == *debug ]] ; then 
    export VERSION=${VERSION}_debug
    echo "DEBUG"
    export IS_DEBUG=true
fi

if [[ "${CCACHE_RECACHE}" == true ]]; then
    ccache -C
fi

cd ${TYPESAFETY_FOLDER}/chromium
${TYPESAFETY_FOLDER}/chromium/get_deps.sh
cd -

if [[ $# -eq 0 || ( $1 == typepp* && $1 != typepp_collect ) ]] ; then
    cd /home/nbadoux/chromium/third_party
    patch -f -p1 < ${TYPESAFETY_FOLDER}/chromium/patch/third_party.patch
    cd -
    cd /home/nbadoux/chromium/v8 
    patch -f -p1 < ${TYPESAFETY_FOLDER}/chromium/patch/v8.patch
    cd -
fi

export PKG_CONFIG_PATH="/usr/share/pkgconfig"
sudo cp ${TYPESAFETY_FOLDER}/chromium/harfbuzz-subset.pc ${PKG_CONFIG_PATH}
sudo cp ${TYPESAFETY_FOLDER}/chromium/hb-subset-cff1.cc ${CHROMIUM_FOLDER}/third_party/harfbuzz-ng/src/src/hb-subset-cff1.cc
sudo cp ${TYPESAFETY_FOLDER}/chromium/png_decoder.cpp ${CHROMIUM_FOLDER}/third_party/pdfium/core/fxcodec/png/png_decoder.cpp
sudo cp ${TYPESAFETY_FOLDER}/chromium/Memset.hpp ${CHROMIUM_FOLDER}/third_party/swiftshader/src/Device/Memset.hpp


SKIP=true

export LD_LIBRARY_PATH="${LLVM_BUILD_DIR}/../libunwind-build${FOR_PROGRAM}/lib/"
export AR="${LLVM_BUILD_DIR}/bin/llvm-ar"
export NM="${LLVM_BUILD_DIR}/bin/llvm-nm"
export CC="${LLVM_BUILD_DIR}/bin/clang"
export CXX="${LLVM_BUILD_DIR}/bin/clang++"

# have to change this

export PATH+=":/usr/local/bin"

# more verbose linker output
export LDFLAGS+="-Wl,--stats "


# initial flags from dpkg-buildflags
export DEB_CXXFLAGS_MAINT_STRIP="-g "
export CXXFLAGS+=$(dpkg-buildflags --get CXXFLAGS)


export CXXFLAGS+=" -Wno-conversion \
  -Wno-unused-function \
  -Wno-unused-variable \
  -Wno-unused-private-field \
  -Wno-deprecated-declarations \
  -Wno-unused-command-line-argument \
  -Wno-unused-but-set-variable \
  -Wno-unknown-pragmas \
  -Wno-psabi \
  -Wno-delete-non-abstract-non-virtual-dtor \
  -Wno-deprecated-copy \
  -Wno-non-virtual-dtor \
  -Wno-deprecated-copy \
  -Wno-builtin-assume-aligned-alignment \
  -Wno-implicit-int-conversion \
  -Wno-c++98-compat-extra-semi \
	-Wno-macro-redefined \
  -nostdinc++ \
  -I${LLVM_BUILD_DIR}/../libcxx-build/include/c++/v1 \
   -lc++ \
  "


export LDFLAGS+=" -Wl,-rpath,${TYPEPLUS_LOG_PATH}/libcxxabi-build${FOR_PROGRAM}/lib \
									-L${TYPEPLUS_LOG_PATH}/libcxxabi-build${FOR_PROGRAM}/lib \
									-Wl,-rpath,${TYPEPLUS_LOG_PATH}/libcxx-build${FOR_PROGRAM}/lib \
									-L${TYPEPLUS_LOG_PATH}/libcxx-build${FOR_PROGRAM}/lib \
									-stdlib=libc++"
                                    

# disable clang plugins
defines="clang_use_chrome_plugins=false "


# do we need this?
# build using system toolchain
defines+="host_toolchain=\"//build/toolchain/linux/unbundle:default\" "
defines+="custom_toolchain=\"//build/toolchain/linux/unbundle:default\" "

# set the appropriate cpu architecture
DEB_HOST_ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)
# ifeq (i386,DEB_HOST_ARCH)
# defines+="host_cpu=\"x86\" symbol_level=0 "
# endif
# ifeq (amd64,DEB_HOST_ARCH)
# defines+="host_cpu=\"x64\" "
# endif
# ifeq (arm64,DEB_HOST_ARCH)
# defines+="host_cpu=\"arm64\" "
# endif
# ifeq (armhf,DEB_HOST_ARCH)
# defines+="host_cpu=\"arm\" arm_use_neon=false symbol_level=0 "
# endif

echo 
if [[ $DEB_HOST_ARCH == "i386" ]]
then
	defines+="host_cpu=\"x86\" symbol_level=2 "
elif [[ $DEB_HOST_ARCH == "amd64" ]]
then
	defines+="host_cpu=\"x64\" "
elif [[ $DEB_HOST_ARCH == "arm64" ]]
then
	defines+="host_cpu=\"arm64\" "
elif [[ $DEB_HOST_ARCH == "armhf" ]]
then
	defines+="host_cpu=\"arm\" arm_use_neon=false symbol_level=2 ";
fi

# disabled features
defines+="is_debug=${IS_DEBUG} \
cc_wrapper=\"env CCACHE_COMMENTS=1 CCACHE_DEPEND=1 CCACHE_DIRECT=1 CCACHE_CPP2=1 CCACHE_SLOPPINESS=time_macros,include_file_mtime CCACHE_STATS=1 /usr/bin/ccache\" \
clang_use_chrome_plugins = false \
symbol_level=2 \
use_goma=false \
use_vaapi=false \
use_sysroot=false \
use_allocator=\"none\" \
use_libjpeg_turbo=true \
libcxx_abi_unstable=false \
use_custom_libcxx=true \
use_gnome_keyring=false \
use_unofficial_version_number=false \
enable_vr=false \
enable_nacl=false \
enable_nacl_nonsfi=false \
enable_swiftshader=false \
enable_reading_list=false \
enable_one_click_signin=false \
enable_iterator_debugging=false \
enable_hangout_services_extension=false \
optimize_webui=false \
enable_js_type_check=false \
blink_symbol_level=2 \
treat_warnings_as_errors=false \
"


# enabled features
defines+="use_gio=true \
clang_base_path=\"${LLVM_BUILD_DIR}\" \
is_cfi=false \
use_cfi_cast=false \
use_cfi_diag=false \
use_cfi_recover=false \
use_cfi_icall=false \
use_thin_lto=true \
use_pulseaudio=true \
link_pulseaudio=true \
enable_widevine=true \
v8_enable_backtrace=true \
use_system_zlib=true \
use_system_lcms2=true \
use_system_libpng=true \
use_system_libjpeg=false \
use_libjpeg_turbo=true \
use_system_freetype=true \
use_system_harfbuzz=false \
use_system_libopenjpeg2=true \
proprietary_codecs=true \
ffmpeg_branding=\"Chrome\" \
fieldtrial_testing_like_official_build=true \
enable_one_click_signin=true \
"

# handle parallel build options
njobs=35
# ifneq (,$(filter parallel=%,$(DEB_BUILD_OPTIONS)))
# njobs=$(patsubst parallel=%,%,$(filter parallel=%,$(DEB_BUILD_OPTIONS)))
# endif


if [ "${CLASS_INSTRUMENTATION}" = true ]; then \
    \cat ${TYPESAFETY_FOLDER}/chromium/merged.txt | LC_COLLATE=C sort -u > ${TYPESAFETY_FOLDER}/chromium/merged2.txt && mv ${TYPESAFETY_FOLDER}/chromium/merged2.txt ${TYPESAFETY_FOLDER}/chromium/merged.txt; \
    cp ${TYPESAFETY_FOLDER}/chromium/merged.txt ${TARGET_TYPE_LIST_PATH}; \
    TYPEPLUS_LOG_PATH=${TYPEPLUS_LOG_PATH} TARGET_TYPE_LIST_PATH=${TARGET_TYPE_LIST_PATH} ${TYPESAFETY_FOLDER}/../cxx_build_for_program.sh; \
fi

echo "BOOTSTRAP START"
# -j was not defined
# ${CHROMIUM_FOLDER}/tools/gn/bootstrap/bootstrap.py --skip-generate-buildfiles  --build-path=out/${VERSION}

echo "BOOTSTRAP DONE\n"

if [[ "${CLASS_INSTRUMENTATION}" == true && "${SKIP}" == true ]]
then
    echo "skip is true"
#    TYPEPLUS_LOG_PATH=${TYPEPLUS_LOG_PATH} CHROMIUM_FOLDER=${CHROMIUM_FOLDER} VERSION=${VERSION} python3 ${TYPESAFETY_FOLDER}/chromium/scripts/cache_miss_new.py add;
     TYPEPLUS_LOG_PATH=${TYPEPLUS_LOG_PATH} 
     CHROMIUM_FOLDER=${CHROMIUM_FOLDER} 
     VERSION=${VERSION}
fi

export LDFLAGS+=" -Wl,-rpath,${TYPEPLUS_LOG_PATH}/libcxxabi-build${FOR_PROGRAM}/lib \
									-L${TYPEPLUS_LOG_PATH}/libcxxabi-build${FOR_PROGRAM}/lib \
									-Wl,-rpath,${TYPEPLUS_LOG_PATH}/libcxx-build${FOR_PROGRAM}/lib \
									-L${TYPEPLUS_LOG_PATH}/libcxx-build${FOR_PROGRAM}/lib \
									-stdlib=libc++ -lc++ "
if [[ $# -eq 0 || $1 == typepp*  || $1 == cfi* ]] ; then
    export LDFLAGS+=" -fsanitize=typeplus -Wl,--rpath,/home/nbadoux/build/lib/clang/13.0.0/lib/linux/ -L/home/nbadoux/build/lib/clang/13.0.0/lib/linux/ -l:libclang_rt.ubsan_standalone_cxx-x86_64.a -l:libclang_rt.ubsan_standalone-x86_64.a -l:libclang_rt.typeplus-x86_64.a "
fi

rm -drf ${CHROMIUM_FOLDER}/out/${VERSION}

# get gn from depot_tools
gn gen out/${VERSION} --args="$defines" --lib_dirs="${TYPEPLUS_LOG_PATH}/libcxxabi-build${FOR_PROGRAM} ${TYPEPLUS_LOG_PATH}/libunwind-build${FOR_PROGRAM}	${TYPEPLUS_LOG_PATH}/libcxx-build${FOR_PROGRAM}" --ldflags="-stdlibc=libc++"

# -j$(njobs)
ninja  -C   out/${VERSION} chrome chrome_sandbox content_shell chromedriver
cp out/${VERSION}/chrome out/${VERSION}/chromium
cp out/${VERSION}/content_shell out/${VERSION}/chromium-shell
cp out/${VERSION}/chrome_sandbox out/${VERSION}/chrome-sandbox
cp out/${VERSION}/locales/en-US.pak out/${VERSION}/resources
sed -e s/@@PACKAGE@@/chromium/g -e s/@@MENUNAME@@/chromium/g \
        < chrome/app/resources/manpage.1.in > out/${VERSION}/chromium.1

if [ "${VERSION}" = typepp_collect  ]; then \
    ${TYPESAFETY_FOLDER}/script/merge_typecasting_related_type.py "$TYPEPLUS_LOG_PATH" > "$TARGET_TYPE_LIST_PATH"
fi

#ProgramImpl


# up to chunk, but not included

cd "${TYPESAFETY_FOLDER}"/chromium
