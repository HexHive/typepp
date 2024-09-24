#!/usr/bin/python3

import subprocess
import multiprocessing
import shutil
import tqdm
import os
from dotenv import load_dotenv


def launch_warning(original_clang_command):
    process = multiprocessing.current_process()
    warning_file = os.path.join(warning_folder, "warnings_" + str(process.pid) + ".txt")
    my_env = {
        "LD_LIBRARY_PATH": os.path.join(typesafetyBUILD, "..", "libunwind-build/lib/"),
        "TARGET_TYPE_LIST_PATH": merged_file,
        "WARNING_LOG_PATH": warning_file,
    }
    original_clang_command += (
        " -load "
        + os.path.join(typesafetyBUILD, "lib/TypeXXCodeChecker.so")
        + " -plugin typexx-codecheck -fsyntax-only -Wuninitialized -Wno-builtin-assume-aligned-alignment -Wno-delete-non-abstract-non-virtual-dtor -Wno-non-c-typedef-for-linkage -Wno-final-dtor-non-final-class"
    )
    original_clang_command = original_clang_command.replace(" -v ", " ")
    original_clang_command = original_clang_command.replace(
        "CCACHE_SECONDARY_STORAGE=file:/mnt/sdb CCACHE_DEPEND=1 CCACHE_DIRECT=1 CCACHE_CPP2=1 CCACHE_SLOPPINESS=time_macros CCACHE_BASEDIR=/home/nbadoux/ /usr/bin/ccache",
        "",
    )
    original_clang_command = original_clang_command.replace("-mllvm -cast-obj-opt", "")
    original_clang_command = original_clang_command.replace("typeplus,", "")
    original_clang_command = original_clang_command.replace(",typeplus", "")
    original_clang_command = original_clang_command.replace(
        "-mllvm -apply-vtable-standard", ""
    )
    original_clang_command = original_clang_command.replace(
        "-mllvm -collect-profiling-data", ""
    )
    original_clang_command = original_clang_command.replace(
        "-mllvm -check-unrelated-casting", ""
    )
    original_clang_command = original_clang_command.replace(
        "-mllvm -check-base-to-derived-casting", ""
    )
    original_clang_command = original_clang_command.replace(
        "-fno-split-dwarf-inlining", ""
    )
    original_clang_command = original_clang_command.replace(
     "/home/nbadoux/build/../libcxx-build-for-program/include", "/home/nbadoux/build/include"
    )
    original_clang_command = original_clang_command.replace(
     "../../../libcxx-build-for-program/include", "/home/nbadoux/build/include"
    )

    original_clang_command = original_clang_command.replace(
        "/home/nbadoux/build/bin/clang", typesafetyBUILD + "/bin/clang"
    )

    original_clang_command = original_clang_command.replace(
        "-12", "-13"
    )
    original_clang_command = original_clang_command.replace(
     "-fsanitize-cfi-canonical-jump-tables", ""
    )
    original_clang_command = original_clang_command.replace(
    "-fsanitize-system-blacklist=/home/nbadoux/build/lib/clang/13.0.0/share/cfi_blacklist.txt", ""
    )
    if "../../../tools/gn/src" in original_clang_command:
        cwd = os.path.join(chromium_folder, "ui")
    else:
        cwd = chromium_folder
    if not "-fuse-ld=lld" in original_clang_command:
        res = subprocess.run(original_clang_command, env=my_env, shell=True, cwd=cwd)
        try:
            res.check_returncode()
        except subprocess.CalledProcessError:
            print(original_clang_command)
        pass


ENVIRONMENT_FOLDER = os.environ.get("ENVIRONMENT_FOLDER")
env_patch_str = "environment_patched.sh"
if not ENVIRONMENT_FOLDER or not os.path.isfile(
    os.path.join(ENVIRONMENT_FOLDER, env_patch_str)
):
    print("ENVIRONMENT_FOLDER is not set. Aborting.")
    exit(255)
TYPESAFETY_FOLDER = os.path.join(os.path.dirname(os.path.realpath(__file__)), os.pardir)

print(ENVIRONMENT_FOLDER)
load_dotenv(os.path.join(ENVIRONMENT_FOLDER, env_patch_str))
TEMP_FOLDER = str(os.environ.get("TEMP_FOLDER"))

chromium_tmp = os.path.join(TEMP_FOLDER, "chromium")
chromium_folder = os.path.join(os.environ.get("CHROMIUM_FOLDER"), "out/typepp_checking")
warning_folder = os.path.join(chromium_tmp, "warning")
print(warning_folder)
os.makedirs(warning_folder, exist_ok=True)
merged_file = os.path.join(warning_folder, "merged.txt")
typesafetyLLVM = str(os.environ.get("LLVM_FOLDER"))
typesafetyBUILD = str(os.environ.get("BUILD_FOLDER"))
typehashinfo_file = os.path.join(warning_folder, "typehashinfo.txt")
typeinfo_file = os.path.join(warning_folder, "typeinfo.txt")
print(typehashinfo_file)
print(typeinfo_file)
print(typesafetyBUILD)
print(typesafetyLLVM)
print(merged_file)
try:
    shutil.copyfile(os.path.join(chromium_tmp, "merged.txt"), merged_file)
    shutil.copyfile(os.path.join(chromium_tmp, "typehashinfo.txt"), typehashinfo_file)
    shutil.copyfile(os.path.join(chromium_tmp, "typeinfo.txt"), typeinfo_file)
except FileNotFoundError:
    pass

subprocess.run("sort -u " + typehashinfo_file + " -o " + typehashinfo_file, shell=True)
subprocess.run("sort -u " + typeinfo_file + " -o " + typeinfo_file, shell=True)


# This file is a dump of all clang command (see clang -v) executed during a compilation round of chromium.
# We will rexecute them to get all warnings.
# A zip of this file is located in chromium/data directory
with open("clang_verbose_output.out", "r") as compilation_output_file:
    compilation_output = compilation_output_file.readlines()
    clang_commands = list(
        filter(
            lambda l: str(os.path.join(typesafetyBUILD, "/bin/clang")) in l,
            compilation_output,
        )
    )
    clang_commands = clang_commands[9:]
    clang_commands = list(map(lambda l: l.rstrip("\n"), clang_commands))

    pool = multiprocessing.Pool()

    for _ in tqdm.tqdm(
        pool.imap(launch_warning, clang_commands), total=len(clang_commands)
    ):
        pass
