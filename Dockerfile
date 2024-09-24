# syntax = docker/dockerfile:experimental
FROM ubuntu:20.04 AS reference_user

ARG USERNAME=nbadoux
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG CHROMIUM=Type++/chromium/

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s/bin/zsh $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && chown -R root /usr/lib/sudo/sudoers.so /usr/bin/sudo /usr/lib/sudo \
    && chmod 4755 /usr/bin/sudo \
    && chown -R $USERNAME /home/$USERNAME


USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR ${HOME}

FROM reference_user AS spec_cpu
RUN sudo apt-get -q update && \
	DEBIAN_FRONTEND="noninteractive" sudo apt-get install -qq -y p7zip-full p7zip-rar 
COPY --chown=${USERNAME}:${USERNAME} cpu2006-1.2.iso cpu2017-1.1.8.iso /mnt/
RUN sudo 7z x -o/mnt/cpu2006 /mnt/cpu2006-1.2.iso && sudo 7z x -o/mnt/cpu2017 /mnt/cpu2017-1.1.8.iso && sudo chown -R ${USERNAME} /mnt && sudo chmod +x -R /mnt/* && cd /mnt/cpu2006 && ./install.sh -f -d ${HOME}/cpu2006 && cd /mnt/cpu2017 && ./install.sh -f -d ${HOME}/cpu2017 && sudo rm -drf /mnt

# Build LLVM
FROM reference_user AS reference

RUN --mount=type=cache,target=/var/cache/apt sudo apt-get -q update && \
	DEBIAN_FRONTEND="noninteractive" sudo -E apt-get install -qq -y git \
	clang-12 lld-12 wget tar build-essential make ninja-build cmake gfortran \
	vim python3-distutils ccache zsh zip zsh-syntax-highlighting gdb bat \
	python3-dotenv python3 make  python bison \
	libxshmfence-dev devscripts tmux libmpc-dev autojump htop python3-pip  software-properties-common python3-pytest python3-pytest-xdist

# Make zsh history persitstent
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.zsh_history" \
    && sudo mkdir /commandhistory \
    && sudo touch /commandhistory/.zsh_history \
    && sudo chown -R $USERNAME /commandhistory \
    && echo "$SNIPPET" >> "/home/$USERNAME/.zshrc"

# Default powerline10k theme, no plugins installed, and GDB GEF
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.3/zsh-in-docker.sh)" && \
    echo "source /usr/share/autojump/autojump.sh" >> .zshrc && \
    sed -i "s/plugins=()/plugins=(git)/" .zshrc && \
    bash -c "$(curl -fsSL https://gef.blah.cat/sh)" 

ENV PATH="${PATH}:/home/${USERNAME}/.local/bin:/usr/local/bin"
ENV LLVM_FOLDER=${HOME}/LLVM-typepp
ENV TYPESAFETY_VTABLE=${LLVM_FOLDER}/Type++
ENV ENVIRONMENT_FOLDER=${HOME}

COPY --chown=${USERNAME}:${USERNAME} Type++/requirements.txt .
RUN mkdir -p ${LLVM_FOLDER} /tmp/ccache && \
    pip3 install -r requirements.txt

WORKDIR ${LLVM_FOLDER}
RUN git clone -b release/13.x --single-branch --depth 1 https://github.com/llvm/llvm-project.git ${LLVM_FOLDER} && rm -drf ${LLVM_FOLDER}/.git 
RUN rm -drf clang/examples/clang-interpreter/ && sed -i '6d' clang/examples/CMakeLists.txt && cat clang/examples/CMakeLists.txt
COPY --chown=nbadoux:nbadoux Type++/environment_template.sh ${HOME}/environment_patched.sh
RUN sudo apt install -qq -y texinfo
COPY --chown=nbadoux:nbadoux Type++/*.patch fetch_repos.sh ${LLVM_FOLDER}
RUN  ${LLVM_FOLDER}/fetch_repos.sh
ENV CCACHE_DIR=/dockerccache
RUN --mount=type=cache,target=/dockerccache  sudo chown ${USERNAME}:${USERNAME} ${CCACHE_DIR}
COPY --chown=nbadoux:nbadoux build.sh Makefile ${LLVM_FOLDER}
RUN  --mount=type=cache,target=/dockerccache ${LLVM_FOLDER}/build.sh 
COPY --chown=nbadoux:nbadoux reference/*.sh ${LLVM_FOLDER}
RUN  --mount=type=cache,target=/dockerccache ${LLVM_FOLDER}/cxx_build.sh 

CMD zsh


# SPEC CPU + REFERENCE
FROM reference AS cpu_reference
COPY --chown=${USERNAME}:${USERNAME} --from=spec_cpu ${HOME}/cpu2006 ${HOME}/cpu2006
COPY --chown=${USERNAME}:${USERNAME} --from=spec_cpu ${HOME}/cpu2017 ${HOME}/cpu2017
COPY --chown=${USERNAME}:${USERNAME} Type++/script/*.py ${TYPESAFETY_VTABLE}/script/
COPY --chown=${USERNAME}:${USERNAME} Type++/spec_cpu ${TYPESAFETY_VTABLE}/spec_cpu
WORKDIR ${TYPESAFETY_VTABLE}/spec_cpu/patch
RUN ./official_patches.sh
WORKDIR ${TYPESAFETY_VTABLE}/spec_cpu
ENV LD_LIBRARY_PATH=~/LLVM-typepp/libunwind-build/lib
CMD BASELINE=1 ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh

# SPEC CPU + REFERENCE + MEMORY
FROM cpu_reference AS memory_reference
COPY --chown=${USERNAME}:${USERNAME} Type++/script/wss_install.sh ${TYPESAFETY_VTABLE}/script/wss_install.sh
RUN ${TYPESAFETY_VTABLE}/script/wss_install.sh
CMD BASELINE=1 MEMORY=-m ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh

# SPEC_CPU + CFI
FROM cpu_reference AS cpu_cfi
CMD CFI=1 ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh

# SPEC CPU + CFI + MEMORY
FROM cpu_cfi AS memory_cfi
COPY --chown=${USERNAME}:${USERNAME} Type++/script/wss_install.sh ${TYPESAFETY_VTABLE}/script/wss_install.sh
RUN ${TYPESAFETY_VTABLE}/script/wss_install.sh
CMD CFI=1 MEMORY=-m ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh


# TYPEPP
FROM reference AS typepp
ENV TYPEPP=TRUE
COPY --chown=${USERNAME}:${USERNAME} *.sh ${LLVM_FOLDER}/
COPY --chown=${USERNAME}:${USERNAME} Type++/script/*.py ${TYPESAFETY_VTABLE}/script/
COPY --chown=${USERNAME}:${USERNAME} libunwind ${LLVM_FOLDER}/libunwind
COPY --chown=${USERNAME}:${USERNAME} libcxxabi ${LLVM_FOLDER}/libcxxabi
COPY --chown=${USERNAME}:${USERNAME} libcxx ${LLVM_FOLDER}/libcxx
COPY --chown=${USERNAME}:${USERNAME} compiler-rt ${LLVM_FOLDER}/compiler-rt
COPY --chown=${USERNAME}:${USERNAME} clang ${LLVM_FOLDER}/clang
COPY --chown=${USERNAME}:${USERNAME} llvm ${LLVM_FOLDER}/llvm
RUN --mount=type=cache,target=/dockerccache/ sudo chown ${USERNAME}:${USERNAME} /dockerccache
RUN --mount=type=cache,target=/dockerccache/ ./build.sh
RUN --mount=type=cache,target=/dockerccache/ ./cxx_build.sh
CMD zsh
ENV TYPEPP=

FROM typepp AS test_typepp
CMD zsh

FROM typepp AS example_typepp
COPY --chown=${USERNAME}:${USERNAME} Type++/example ${TYPESAFETY_VTABLE}/example
WORKDIR ${TYPESAFETY_VTABLE}/example
CMD zsh

FROM typepp AS microbenchmark
COPY --chown=${USERNAME}:${USERNAME} Type++/metadata-eval ${TYPESAFETY_VTABLE}/metadata-eval
WORKDIR ${TYPESAFETY_VTABLE}/metadata-eval/hextype
RUN make clean && make -j 8
CMD ./benchmark

# SPEC CPU + TYPEPP
FROM typepp AS cpu_typepp_unpatch
COPY --chown=${USERNAME}:${USERNAME} --from=spec_cpu ${HOME}/cpu2006 ${HOME}/cpu2006
COPY --chown=${USERNAME}:${USERNAME} --from=spec_cpu ${HOME}/cpu2017 ${HOME}/cpu2017
COPY --chown=${USERNAME}:${USERNAME} Type++/script/*.py ${TYPESAFETY_VTABLE}/script/
COPY --chown=${USERNAME}:${USERNAME} Type++/spec_cpu ${TYPESAFETY_VTABLE}/spec_cpu
WORKDIR ${TYPESAFETY_VTABLE}/spec_cpu/patch

# SPEC CPU + TYPEPP + PATCH
FROM cpu_typepp_unpatch AS cpu_typepp
RUN ./apply_patches.sh
WORKDIR ${TYPESAFETY_VTABLE}/spec_cpu
ENV LD_LIBRARY_PATH=${LLVM_FOLDER}/libunwind-build-for-program/lib
CMD TYPEPP=1 ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh

# SPEC CPU + TYPEPP + MEMORY
FROM cpu_typepp AS memory_typepp
COPY --chown=${USERNAME}:${USERNAME} Type++/script/wss_install.sh ${TYPESAFETY_VTABLE}/script/wss_install.sh
RUN ${TYPESAFETY_VTABLE}/script/wss_install.sh
CMD TYPEPP=1 MEMORY=-m ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh

# SPEC CPU + TYPEPP + STATS
FROM cpu_typepp AS cpu_typepp_stats
CMD TYPEPP=1 STATS="-stats" ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh


# SPEC CPU + TYPEPP + ANALYSIS
FROM cpu_typepp_unpatch AS cpu_typepp_analysis
RUN ./official_patches.sh
WORKDIR ${TYPESAFETY_VTABLE}/spec_cpu
RUN --mount=type=cache,target=/var/cache/apt sudo apt-get -q update && \
	DEBIAN_FRONTEND="noninteractive" sudo -E apt-get install -qq -y cloc
CMD ANALYSIS=1 ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh

# CFI + stats
FROM typepp AS cfi_stats
ENV CFI=TRUE
COPY --chown=${USERNAME}:${USERNAME} cfi/build.sh cfi/Makefile ${LLVM_FOLDER}/
RUN  --mount=type=cache,target=/dockerccache ./build.sh
COPY --chown=${USERNAME}:${USERNAME} cfi/*.sh ${LLVM_FOLDER}/
COPY --chown=${USERNAME}:${USERNAME} Type++/script/*.py ${TYPESAFETY_VTABLE}/script/
RUN  --mount=type=cache,target=/dockerccache ./cxx_build.sh
ENV CFI=
CMD zsh


# SPEC CPU + CFI + STATS
FROM cfi_stats AS cpu_cfi_stats
COPY --chown=${USERNAME}:${USERNAME} --from=spec_cpu ${HOME}/cpu2006 ${HOME}/cpu2006
COPY --chown=${USERNAME}:${USERNAME} --from=spec_cpu ${HOME}/cpu2017 ${HOME}/cpu2017
COPY --chown=${USERNAME}:${USERNAME} Type++/script/*.py ${TYPESAFETY_VTABLE}/script/
COPY --chown=${USERNAME}:${USERNAME} Type++/spec_cpu ${TYPESAFETY_VTABLE}/spec_cpu
WORKDIR ${TYPESAFETY_VTABLE}/spec_cpu/patch
RUN ./official_patches.sh
WORKDIR ${TYPESAFETY_VTABLE}/spec_cpu
ENV LD_LIBRARY_PATH=~/LLVM-typepp/libunwind-build/lib
CMD CFI=1 STATS="-stats" ${TYPESAFETY_VTABLE}/spec_cpu/run_spec_in_docker.sh


# CHROMIUM + BASELINE
FROM typepp AS chromium_normal
RUN wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && sudo ./llvm.sh 13 all
RUN sudo apt-get -q update && \
	DEBIAN_FRONTEND="noninteractive" sudo apt-get install -qq -y \
    libnss3-dev pkg-config git libcups2-dev libopenjp2-7-dev liblcms2-dev mesa-common-dev  libgl1-mesa-dev libgbm-dev build-essential \
    libgtk-3-dev librust-pangocairo-dev libdbus-glib-1-dev libgirepository1.0-dev libatk1.0-dev libpulse-dev libxkbcommon-dev libdrm-dev \
    libpci-dev gperf  libjsoncpp1 libjsoncpp-dev libasound2-dev libkrb5-dev
RUN git clone  https://github.com/jordansissel/xdotool.git && cd xdotool && git checkout edbbb7a8f664ceacbb2cffbe8ee4f5a26b5addc8 && sudo make install && cd .. && rm -drf xdotool
RUN sudo ln -s /usr/bin/lld-13 /usr/bin/lld && sudo ln -s /usr/bin/lld-13 /usr/bin/ld.lld
COPY --chown=${USERNAME}:${USERNAME} Type++/chromium/chromium-baseline /home/nbadoux/chromium/
RUN /home/${USERNAME}/chromium/build/install-build-deps.sh
COPY --chown=${USERNAME}:${USERNAME} ${CHROMIUM}/gclient_cfg ${TYPESAFETY_VTABLE}/chromium/gclient_cfg
COPY --chown=${USERNAME}:${USERNAME} ${CHROMIUM}/get_deps.sh ${TYPESAFETY_VTABLE}/chromium/get_deps.sh
WORKDIR ${TYPESAFETY_VTABLE}/chromium
RUN ./get_deps.sh
RUN sudo mkdir /dockerccache && sudo chown nbadoux:nbadoux /dockerccache 
ENV VERSION=ref

FROM chromium_normal AS chromium_baseline
CMD ./build_chromium.sh ref && ./eval/eval.sh ref

FROM chromium_normal AS chromium_cfi
CMD ./build_chromium.sh cfi && ./eval/eval.sh cfi

# CHROMIUM + TYPEPP
FROM typepp AS chromium_typepp_start
RUN wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && sudo ./llvm.sh 13 all
RUN sudo apt-get -q update && \
	DEBIAN_FRONTEND="noninteractive" sudo apt-get install -qq -y \
    libnss3-dev pkg-config git libcups2-dev libopenjp2-7-dev liblcms2-dev mesa-common-dev  libgl1-mesa-dev libgbm-dev build-essential \
    libgtk-3-dev librust-pangocairo-dev libdbus-glib-1-dev libgirepository1.0-dev libatk1.0-dev libpulse-dev libxkbcommon-dev libdrm-dev \
    libpci-dev gperf  libjsoncpp1 libjsoncpp-dev libasound2-dev libkrb5-dev
RUN git clone  https://github.com/jordansissel/xdotool.git && cd xdotool && git checkout edbbb7a8f664ceacbb2cffbe8ee4f5a26b5addc8 && sudo make install && cd .. && rm -drf xdotool
RUN sudo ln -s /usr/bin/lld-13 /usr/bin/lld && sudo ln -s /usr/bin/lld-13 /usr/bin/ld.lld

FROM chromium_typepp_start AS chromium_typepp_normal
COPY --chown=${USERNAME}:${USERNAME} Type++/chromium/chromium-typepp /home/nbadoux/chromium/
RUN sudo /home/${USERNAME}/chromium/build/install-build-deps.sh
COPY --chown=${USERNAME}:${USERNAME} ${CHROMIUM}/gclient_cfg ${TYPESAFETY_VTABLE}/chromium/gclient_cfg
COPY --chown=${USERNAME}:${USERNAME} ${CHROMIUM}/get_deps.sh ${TYPESAFETY_VTABLE}/chromium/get_deps.sh
WORKDIR ${TYPESAFETY_VTABLE}/chromium
RUN ./get_deps.sh
RUN sudo mkdir /dockerccache && sudo chown nbadoux:nbadoux /dockerccache 
ENV VERSION=typepp

FROM chromium_typepp_normal AS chromium_typepp
CMD ./build_chromium.sh typepp_checking && ./eval/eval.sh typepp_checking

FROM chromium_typepp_normal AS chromium_typepp_profiling
CMD ./build_chromium.sh typepp_checking_profiling && ./eval/eval.sh typepp_checking_profiling

# CHROMIUM + TYPEPP + CFI
FROM chromium_typepp_start AS chromium_cfi_stats
COPY --chown=${USERNAME}:${USERNAME} Type++/chromium/chromium-baseline /home/nbadoux/chromium/
RUN sudo /home/${USERNAME}/chromium/build/install-build-deps.sh
COPY --chown=${USERNAME}:${USERNAME} ${CHROMIUM}/gclient_cfg ${TYPESAFETY_VTABLE}/chromium/gclient_cfg
COPY --chown=${USERNAME}:${USERNAME} ${CHROMIUM}/get_deps.sh ${TYPESAFETY_VTABLE}/chromium/get_deps.sh
WORKDIR ${TYPESAFETY_VTABLE}/chromium
RUN ./get_deps.sh
RUN sudo mkdir /dockerccache && sudo chown nbadoux:nbadoux /dockerccache 
CMD ./build_chromium.sh cfi_stats && ./eval/eval.sh cfi_stats
