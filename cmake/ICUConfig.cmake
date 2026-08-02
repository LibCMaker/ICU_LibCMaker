# ****************************************************************************
#  Project:  LibCMaker
#  Purpose:  A CMake build scripts for build libraries with CMake
#  Author:   NikitaFeodonit, nfeodonit@yandex.com
# ****************************************************************************
#    Copyright (c) 2017-2026 NikitaFeodonit
#
#    This file is part of the LibCMaker project.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published
#    by the Free Software Foundation, either version 3 of the License,
#    or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#    See the GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program. If not, see <http://www.gnu.org/licenses/>.
# ****************************************************************************


cmake_policy(PUSH)


#-----------------------------------------------------------------------
# Library version
#-----------------------------------------------------------------------

set(ICU_VERSION "78.3" CACHE STRING "ICU_VERSION")
set(ICU_sha256
  "3a2e7a47604ba702f345878308e6fefeca612ee895cf4a5f222e7955fabfe0c0"
  CACHE STRING "ICU_sha256"
)


#-----------------------------------------------------------------------
# ICU options
#-----------------------------------------------------------------------

# TODO: ICU options.
# "--enable-extras=yes"
# "--enable-icuio=yes"
# "--enable-tools=yes"


#-----------------------------------------------------------------------
# Define LibCMaker dirs, includes and vars
#-----------------------------------------------------------------------

if(NOT LibCMaker_DIR)
  message(FATAL_ERROR "LibCMaker_DIR is not defined.")
endif()

include("${LibCMaker_DIR}/cmake/cmr_get_cmake_min_ver.cmake" NO_POLICY_SCOPE)
cmr_get_cmake_min_ver()
cmake_minimum_required(VERSION ${cmr_CMAKE_MIN_VER})

include("${LibCMaker_DIR}/cmake/cmr_functions.cmake")

if(NOT cmr_BUILD_MULTIPROC_CNT)
  set(cmr_BUILD_MULTIPROC_CNT "1")
endif()


#-----------------------------------------------------------------------
# Unpack, configure and build the required libraries
#-----------------------------------------------------------------------

include(FetchContent)

set(icu_SRC_NAME "icu4c-${ICU_VERSION}")
set(icu_ARCHIVE_DIR "${CMAKE_CURRENT_LIST_DIR}/source")

FetchContent_Declare(
  ICU
  URL "${icu_ARCHIVE_DIR}/${icu_SRC_NAME}-sources.tgz"
  URL_HASH SHA256=${ICU_sha256}
  OVERRIDE_FIND_PACKAGE
  SOURCE_SUBDIR not_exist
)

FetchContent_MakeAvailable(ICU)

FetchContent_GetProperties(ICU
  SOURCE_DIR ICU_FETCH_SOURCE_DIR
  BINARY_DIR ICU_FETCH_BINARY_DIR
)


#-----------------------------------------------------------------------
# Paths
#-----------------------------------------------------------------------

set(icu_PATCH_DIR "${icu_ARCHIVE_DIR}/patch/${icu_SRC_NAME}")
set(icu_SRC_DIR   "${ICU_FETCH_SOURCE_DIR}")
set(icu_BUILD_DIR "${ICU_FETCH_BINARY_DIR}")


#-----------------------------------------------------------------------
# Patches
#-----------------------------------------------------------------------

find_package(Git 2.17.1 REQUIRED)

# Init git repo for apply patches.
# Since this directory may be located in a subdirectory of the main repository.
# Or use 'git rev-parse --show-prefix' with '--directory' in 'git apply' for it.
execute_process(
  COMMAND ${GIT_EXECUTABLE} init
  OUTPUT_VARIABLE icu_REPO_PREFIX
  OUTPUT_STRIP_TRAILING_WHITESPACE
  WORKING_DIRECTORY ${icu_SRC_DIR}
)

function(apply_source_patch _name)
  set(${_name}_STAMP
    "${icu_BUILD_DIR}/stamp__patch__${_name}__.stamp"
  )
  if(NOT EXISTS ${${_name}_STAMP})
    cmr_print_status("Apply ICU source patch: '${_name}'")
    set(${_name}_FILE
      "${icu_PATCH_DIR}/${_name}"
    )

    # execute_process(
    #   COMMAND ${GIT_EXECUTABLE} rev-parse --show-prefix
    #   OUTPUT_VARIABLE icu_REPO_PREFIX
    #   OUTPUT_STRIP_TRAILING_WHITESPACE
    #   WORKING_DIRECTORY ${icu_MAIN_SRC_DIR}
    # )

    execute_process(
      COMMAND ${GIT_EXECUTABLE} apply
        # --reverse
        --unsafe-paths
        # --directory=${icu_REPO_PREFIX}
        "${${_name}_FILE}"
      WORKING_DIRECTORY ${icu_SRC_DIR}
      RESULT_VARIABLE res_${_name}
      COMMAND_ECHO STDERR
    )

    if (res_${_name})
      cmr_print_error("Failed patch ${_name}: ${res_${_name}}")
    endif()
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E touch ${${_name}_STAMP}
    )
  endif()
endfunction()

apply_source_patch("source_data_Makefile_in__mkdir_TMP_DIR.patch")


#-----------------------------------------------------------------------
# OS specifics
#-----------------------------------------------------------------------

if(WIN32)
  set(target_os "win")
elseif(IOS)
  set(target_os "ios")
elseif(APPLE)
  set(target_os "mac")
elseif(ANDROID)
  set(target_os "android")
elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Linux")
  set(target_os "linux")
else()
  cmr_print_error("Unsupported platform.")
endif()

set(_is_win false)
set(_is_ios false)
set(_is_mac false)
set(_is_android false)
set(_is_linux false)
set(_is_${target_os} true)

set(is_win ${_is_win} CACHE STRING "is_win")
set(is_ios ${_is_ios} CACHE STRING "is_ios")
set(is_mac ${_is_mac} CACHE STRING "is_mac")
set(is_android ${_is_android} CACHE STRING "is_android")
set(is_linux ${_is_linux} CACHE STRING "is_linux")

# TODO: from Skia.
string(APPEND icu_GN_ARGS " target_os=\"${target_os}\"")

if(is_android)
  if(ANDROID_NDK_MAJOR LESS 22)
    cmr_print_error("Android NDK r22+ is required.")
  endif()

  set(ndk ${CMAKE_ANDROID_NDK})
  set(ndk_api ${CMAKE_SYSTEM_VERSION})

  if(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
    set(target_cpu "arm")
  elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
    set(target_cpu "arm64")
  elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86")
    set(target_cpu "x86")
  elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
    set(target_cpu "x64")
  else()
    cmr_print_error("Unsupported CPU arch.")
  endif()

  if(is_android AND DEFINED ndk_api AND ndk_api VERSION_GREATER_EQUAL 30)
    set(_icu_use_ndk_images true)
  endif()

  # TODO: from Skia.
  string(APPEND icu_GN_ARGS " ndk=\"${ndk}\"")
  string(APPEND icu_GN_ARGS " ndk_api=${ndk_api}")
  string(APPEND icu_GN_ARGS " target_cpu=\"${target_cpu}\"")
endif()


#-----------------------------------------------------------------------
# Find required compilers
#-----------------------------------------------------------------------

include(CheckLanguage)

check_language(ASM)
if(CMAKE_ASM_COMPILER)
  enable_language(ASM)
else()
  cmr_print_error("No ASM support.")
endif()

check_language(C)
if(CMAKE_C_COMPILER)
  enable_language(C)
else()
  cmr_print_error("No C support.")
endif()

check_language(CXX)
if(CMAKE_CXX_COMPILER)
  enable_language(CXX)
else()
  cmr_print_error("No CXX support.")
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
    AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9.0.0)
  cmr_print_error("GNU g++ compiler version 9+ is required.")
endif()

if((CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"
     OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
     AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 9.0.0)
  cmr_print_error("Clang compiler version 9+ is required.")
endif()

if(MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 19.15)
  cmr_print_error("MSVC compiler version 19.15+ is required.")
endif()

# TODO: from Skia.
if(is_linux OR is_mac OR MINGW)  # TODO: if CMake gen = "Unix Makefiles"
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
      OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang"
      OR CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")

    #  ar = "ar"
    #  cc = "cc"
    #  cxx = "c++"
    if(CMAKE_C_COMPILER)
      string(APPEND icu_GN_ARGS " cc=\"${CMAKE_C_COMPILER}\"")
    endif()
    if(CMAKE_CXX_COMPILER)
      string(APPEND icu_GN_ARGS " cxx=\"${CMAKE_CXX_COMPILER}\"")
    endif()
    if(CMAKE_AR)
      string(APPEND icu_GN_ARGS " ar=\"${CMAKE_AR}\"")
    endif()

    #  cc_wrapper = ""
    if(CMAKE_CXX_COMPILER_LAUNCHER)
      string(APPEND icu_GN_ARGS
        " cc_wrapper=\"${CMAKE_CXX_COMPILER_LAUNCHER}\""
      )
    endif()
  endif()
endif()

# TODO: from Skia.
if(is_win AND MSVC)
  #  win_sdk = "C:/Program Files (x86)/Windows Kits/10"
  #  win_sdk_version = ""
  #  win_vc = ""
  #  win_toolchain_version = ""
  #  clang_win = ""
  #  clang_win_version = ""

  if(cmr_VS_TOOLSET_DIR)
    string(APPEND icu_GN_ARGS " win_vc=\"${cmr_VS_TOOLSET_DIR}\"")
  endif()
  if(cmr_VS_TOOLSET_VERSION)
    string(APPEND icu_GN_ARGS " win_toolchain_version=\"${cmr_VS_TOOLSET_VERSION}\"")
  endif()
  if(cmr_WINDOWS_KITS_DIR)
    string(APPEND icu_GN_ARGS " win_sdk=\"${cmr_WINDOWS_KITS_DIR}\"")
  endif()
  if(cmr_WINDOWS_KITS_VERSION)
    string(APPEND icu_GN_ARGS " win_sdk_version=\"${cmr_WINDOWS_KITS_VERSION}\"")
  endif()

  if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM")
    set(target_cpu "arm")
  elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    set(target_cpu "arm64")
  elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "Win32")
    set(target_cpu "x86")
  elseif(CMAKE_GENERATOR_PLATFORM STREQUAL "x64")
    set(target_cpu "x64")
  else()
    cmr_print_error("Unsupported CPU arch.")
  endif()

  string(APPEND icu_GN_ARGS " target_cpu=\"${target_cpu}\"")

  # TODO: clang_win
  #  clang_win = ""
  #  clang_win_version = ""
  # NOTE: https://icu.org/docs/user/build/#highly-recommended-build-with-clang-cl
endif()

# TODO: from Skia.
if(XCODE)
  if(is_mac AND CMAKE_OSX_SYSROOT)
    string(APPEND icu_GN_ARGS " xcode_sysroot=\"${CMAKE_OSX_SYSROOT}\"")
  endif()
  if(is_ios AND CMAKE_OSX_SYSROOT_INT)
    string(APPEND icu_GN_ARGS " xcode_sysroot=\"${CMAKE_OSX_SYSROOT_INT}\"")
  endif()
endif()

# TODO: from Skia.
if(is_ios)
  if(ARCHS STREQUAL "armv7")
    set(target_cpu "arm")
  elseif(ARCHS STREQUAL "arm64")
    set(target_cpu "arm64")
  elseif(ARCHS STREQUAL "i386")
    set(target_cpu "x86")
  elseif(ARCHS STREQUAL "x86_64")
    set(target_cpu "x64")
  else()
    cmr_print_error("Unsupported CPU arch.")
  endif()

  string(APPEND icu_GN_ARGS " target_cpu=\"${target_cpu}\"")

  # ios_min_target = ""
  if(DEPLOYMENT_TARGET)
    string(APPEND icu_GN_ARGS " ios_min_target=\"${DEPLOYMENT_TARGET}\"")
  endif()
endif()


#-----------------------------------------------------------------------
# Compiler flags
#-----------------------------------------------------------------------

if(WIN32 AND MSVC)
  set(flag_MT_MD_sfx "$<$<CONFIG:Debug>:d>")

  if(BUILD_SHARED_LIBS)
    string(APPEND icu_FLAGS " /MD${flag_MT_MD_sfx}")
  else()
    string(APPEND icu_FLAGS " /MT${flag_MT_MD_sfx}")
  endif()

  if(TARGETING_XP_64 OR TARGETING_XP)
    string(APPEND icu_FLAGS " /D_ATL_XP_TARGETING")
  endif()
endif()

string(APPEND icu_ASFLAGS " ${icu_FLAGS} ${CMAKE_ASM_FLAGS}")
string(APPEND icu_ASFLAGS " $<$<CONFIG:Debug>:${CMAKE_ASM_FLAGS_DEBUG}>")
string(APPEND icu_ASFLAGS " $<$<CONFIG:Release>:${CMAKE_ASM_FLAGS_RELEASE}>")

string(APPEND icu_CFLAGS " ${icu_FLAGS} ${CMAKE_C_FLAGS}")
string(APPEND icu_CFLAGS " $<$<CONFIG:Debug>:${CMAKE_C_FLAGS_DEBUG}>")
string(APPEND icu_CFLAGS " $<$<CONFIG:Release>:${CMAKE_C_FLAGS_RELEASE}>")

string(APPEND icu_CXXFLAGS " ${icu_FLAGS} ${CMAKE_CXX_FLAGS}")
string(APPEND icu_CXXFLAGS " $<$<CONFIG:Debug>:${CMAKE_CXX_FLAGS_DEBUG}>")
string(APPEND icu_CXXFLAGS " $<$<CONFIG:Release>:${CMAKE_CXX_FLAGS_RELEASE}>")

if(BUILD_SHARED_LIBS)
  string(APPEND icu_LDFLAGS " ${CMAKE_SHARED_LINKER_FLAGS}")
  string(APPEND icu_LDFLAGS " $<$<CONFIG:Debug>:${CMAKE_SHARED_LINKER_FLAGS_DEBUG}>")
  string(APPEND icu_LDFLAGS " $<$<CONFIG:Release>:${CMAKE_SHARED_LINKER_FLAGS_RELEASE}>")
else()
  # string(APPEND icu_ASFLAGS " ${CMAKE_ASM_COMPILE_OPTIONS_PIC}")
  # string(APPEND icu_CFLAGS " ${CMAKE_C_COMPILE_OPTIONS_PIC}")
  # string(APPEND icu_CXXFLAGS " ${CMAKE_CXX_COMPILE_OPTIONS_PIC}")

  string(APPEND icu_LDFLAGS " ${CMAKE_STATIC_LINKER_FLAGS}")
  string(APPEND icu_LDFLAGS " $<$<CONFIG:Debug>:${CMAKE_STATIC_LINKER_FLAGS_DEBUG}>")
  string(APPEND icu_LDFLAGS " $<$<CONFIG:Release>:${CMAKE_STATIC_LINKER_FLAGS_RELEASE}>")

  # For Android:
  #string(APPEND icu_LDFLAGS " -static-libstdc++")
endif()


# For Android:
#
# Sysroot
# https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#sysroot
# "Clang will automatically select the sysroot"
#
# STL libc++
# https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#libc
# To use the static variant, pass -static-libstdc++ when linking
# If using the shared variant, libc++_shared.so must be included in the APK.
# This library is installed to <NDK>/sysroot/usr/lib/<triple>.


#-----------------------------------------------------------------------
# Define env
#-----------------------------------------------------------------------

# Some influential environment variables:
#   CC          C compiler command
#   CFLAGS      C compiler flags
#   LDFLAGS     linker flags, e.g. -L<lib dir> if you have libraries in a
#               nonstandard directory <lib dir>
#   LIBS        libraries to pass to the linker, e.g. -l<library>
#   CPPFLAGS    (Objective) C/C++ preprocessor flags, e.g. -I<include dir> if
#               you have headers in a nonstandard directory <include dir>
#   CXX         C++ compiler command
#   CXXFLAGS    C++ compiler flags
#   PKG_CONFIG  path to pkg-config utility
#   PKG_CONFIG_PATH
#               directories to add to pkg-config's search path
#   PKG_CONFIG_LIBDIR
#               path overriding pkg-config's built-in search path
#   ICULEHB_CFLAGS
#               C compiler flags for ICULEHB, overriding pkg-config
#   ICULEHB_LIBS
#               linker flags for ICULEHB, overriding pkg-config
#   CPP         C preprocessor

# ICULEHB_CFLAGS and ICULEHB_LIBS are for 'icu-le-hb'.

set(ICU_ENV
  "AS=${CMAKE_ASM_COMPILER}"
  "CC=${CMAKE_C_COMPILER}"
  "CXX=${CMAKE_CXX_COMPILER}"
  # "CPP=${UNKNOWN_CMAKE_CPP}"

  "ASFLAGS=${icu_ASFLAGS}"
  "CFLAGS=${icu_CFLAGS}"      # for C, ex. -srd=c99
  "CXXFLAGS=${icu_CXXFLAGS}"  # for C++, ex. -std=c++14
  # "CPPFLAGS=${icu_CPPFLAGS}"  # for include dirs

  "LDFLAGS=${icu_LDFLAGS}"

  "AR=${CMAKE_AR}"
  "LD=${CMAKE_CXX_COMPILER_LINKER}"
  "RANLIB=${CMAKE_RANLIB}"
)

if(BUILD_SHARED_LIBS)
  set(icu_ENABLE_SHARED yes)
  set(icu_ENABLE_STATIC no)
else()
  set(icu_ENABLE_SHARED no)
  set(icu_ENABLE_STATIC yes)
endif()

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(icu_ARCH_BITS 64)
elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
  set(icu_ARCH_BITS 32)
else()
  cmr_print_error("The arch bits are not supported.")
endif()

if(NOT CMAKE_VERBOSE_MAKEFILE)
  # set(icu_MAKE_SILENT --silent)
endif()


#-----------------------------------------------------------------------
# Configure, build and install the ICU library
#-----------------------------------------------------------------------

include(GNUInstallDirs)

# Run 'configure'
set(icu_configure_STAMP "${icu_BUILD_DIR}/stamp__icu_configure.stamp")
add_custom_command(OUTPUT ${icu_configure_STAMP}
  COMMAND ${CMAKE_COMMAND} -E env ${ICU_ENV}
    "${icu_SRC_DIR}/source/configure"

      # find the sources in DIR [configure dir or '..']
      "--srcdir=${icu_SRC_DIR}/source"

      # install architecture-independent files in PREFIX [/usr/local]
      "--prefix=${CMAKE_INSTALL_PREFIX}"
      # install architecture-dependent files in EPREFIX [PREFIX]
      "--exec-prefix=${CMAKE_INSTALL_PREFIX}"

      # user executables [EPREFIX/bin]
      "--bindir=${CMAKE_INSTALL_FULL_BINDIR}"
      # system admin executables [EPREFIX/sbin]
      "--sbindir=${CMAKE_INSTALL_FULL_SBINDIR}"
      # program executables [EPREFIX/libexec]
      "--libexecdir=${CMAKE_INSTALL_FULL_LIBEXECDIR}"
      # read-only single-machine data [PREFIX/etc]
      "--sysconfdir=${CMAKE_INSTALL_FULL_SYSCONFDIR}"
      # modifiable architecture-independent data [PREFIX/com]
      "--sharedstatedir=${CMAKE_INSTALL_FULL_SHAREDSTATEDIR}"
      # modifiable single-machine data [PREFIX/var]
      "--localstatedir=${CMAKE_INSTALL_FULL_LOCALSTATEDIR}"
      # modifiable per-process data [LOCALSTATEDIR/run]
      "--runstatedir=${CMAKE_INSTALL_FULL_RUNSTATEDIR}"
      # object code libraries [EPREFIX/lib]
      "--libdir=${CMAKE_INSTALL_FULL_LIBDIR}"
      # C header files [PREFIX/include]
      "--includedir=${CMAKE_INSTALL_FULL_INCLUDEDIR}"
      # C header files for non-gcc [/usr/include]
      "--oldincludedir=${CMAKE_INSTALL_FULL_OLDINCLUDEDIR}"
      # read-only arch.-independent data root [PREFIX/share]
      "--datarootdir=${CMAKE_INSTALL_FULL_DATAROOTDIR}"
      # read-only architecture-independent data [DATAROOTDIR]
      "--datadir=${CMAKE_INSTALL_FULL_DATADIR}"
      # info documentation [DATAROOTDIR/info]
      "--infodir=${CMAKE_INSTALL_FULL_INFODIR}"
      # locale-dependent data [DATAROOTDIR/locale]
      "--localedir=${CMAKE_INSTALL_FULL_LOCALEDIR}"
      # man documentation [DATAROOTDIR/man]
      "--mandir=${CMAKE_INSTALL_FULL_MANDIR}"
      # documentation root [DATAROOTDIR/doc/PACKAGE]
      "--docdir=${CMAKE_INSTALL_FULL_DOCDIR}"
      # html documentation [DOCDIR]
      "--htmldir=${CMAKE_INSTALL_FULL_DOCDIR}"
      # dvi documentation [DOCDIR]
      "--dvidir=${CMAKE_INSTALL_FULL_DOCDIR}"
      # pdf documentation [DOCDIR]
      "--pdfdir=${CMAKE_INSTALL_FULL_DOCDIR}"
      # ps documentation [DOCDIR]
      "--psdir=${CMAKE_INSTALL_FULL_DOCDIR}"



      # specify how many bits to use for the library
      # (32, 64, 64else32, nochange) default=nochange
      "--with-library-bits=${icu_ARCH_BITS}"

      # build debug libraries and enable the U_DEBUG define
      "--enable-debug=$<IF:$<CONFIG:Debug>,yes,no>"

      # build release libraries
      "--enable-release=$<IF:$<CONFIG:Release>,yes,no>"

      # build shared libraries
      "--enable-shared=${icu_ENABLE_SHARED}"

      # build static libraries
      "--enable-static=${icu_ENABLE_STATIC}"



      # compile with strict compiler options
      "--enable-strict=yes"

      # enable unrecognized --enable/--with options
      "--enable-option-checking=yes"



      ## Successful cross-compilation of ICU often requires first building
      ## the entire library for the --build architecture and passing the path
      ## to it via the --with-cross-build option.
      ##
      ## Host system:
      # --build=x86_64-pc-linux-gnu
      ## Target system:
      # --host=aarch64-unknown-linux-gnu
      ## Path to ICU built for --build (host) system:
      # --with-cross-build=/path/to/icu/built/for/build/system

      # configure for building on BUILD [guessed]
      # --build=BUILD

      # cross-compile to build programs to run on HOST [BUILD]
      # --host=HOST

      # specify an absolute path to the build directory of an ICU built
      # for the current platform default=no cross dir
      # --with-cross-build=dir



      # specify how to package ICU data. Possible values:
      # files    raw files (.res, etc)
      # archive  build a single icudtXX.dat file
      # library  shared library (.dll/.so/etc.)
      # static   static library (.a/.lib/etc.)
      # auto     build shared if possible (default)
      # See https://unicode-org.github.io/icu/userguide/icu_data for more info.
      "--with-data-packaging=archive"  # DATA_PACKAGING_MODE=common

      # build ICU extras
      "--enable-extras=yes"  # U_HAVE_EXTRAS=1

      # build ICU's icuio library
      "--enable-icuio=yes"  # U_HAVE_ICUIO=1

      # build ICU's tools
      # TODO: no for cross-build
      "--enable-tools=yes"  # U_HAVE_TOOLS=1

      # build ICU's Paragraph Layout library.
      # icu-le-hb must be installed via pkg-config. See http://harfbuzz.org
      # (Deprecated. Used only for old progs.)
      "--enable-layoutex=no"  # U_HAVE_LAYOUTEX=0

      # build ICU's fuzzer test targets
      "--enable-fuzzer=no"  # U_HAVE_FUZZER=0

      # build ICU tests
      "--enable-tests=no"  # U_HAVE_TESTS=0

      # build ICU samples
      "--enable-samples=no"  # U_HAVE_SAMPLES=0

      # install icu-config  # deprecated
      "--enable-icu-config=no"  # INSTALL_ICU_CONFIG=false

      # enable draft APIs (and internal APIs)
      "--enable-draft=no"  # U_DEFAULT_SHOW_DRAFT=0

      # add a version suffix to symbols
      "--enable-renaming=no"  # U_DISABLE_RENAMING=1

      # enable function and data tracing
      "--enable-tracing=no"  # U_ENABLE_TRACING=0

      # enable plugins
      "--enable-plugins=no"  # U_HAVE_PLUGINS=0

      # enable dynamic loading
      "--enable-dyload=no"  # U_ENABLE_DYLOAD=0



      # enable auto cleanup of libraries
      # TODO: ???
      "--enable-auto-cleanup=no"  # UCLN_NO_AUTO_CLEANUP==1

      # use rpath when linking default is only if necessary
      # TODO: ???
      "--enable-rpath=no"  # ENABLE_RPATH=NO

      # weakly reference the threading library
      # TODO: ???
      "--enable-weak-threads=no"

      # tag a suffix to the library names default=
      # U_HAVE_LIB_SUFFIX=1, ICULIBSUFFIXCNAME=suffix
      # --with-library-suffix=suffix

  COMMAND ${CMAKE_COMMAND} -E touch ${icu_configure_STAMP}
  WORKING_DIRECTORY ${icu_BUILD_DIR}
  VERBATIM
  COMMENT "Configure ICU library"
)

# Run 'make'
set(icu_build_STAMP "${icu_BUILD_DIR}/stamp__icu_build.stamp")
add_custom_command(OUTPUT ${icu_build_STAMP}
  COMMAND ${CMAKE_COMMAND} -E env ${ICU_ENV}
    ${CMAKE_MAKE_PROGRAM} -j ${cmr_BUILD_MULTIPROC_CNT} ${icu_MAKE_SILENT}
  COMMAND ${CMAKE_COMMAND} -E touch ${icu_build_STAMP}
  WORKING_DIRECTORY ${icu_BUILD_DIR}
  VERBATIM
  COMMENT "Build ICU library"
  DEPENDS ${icu_configure_STAMP}
)

add_custom_target(icu_build
  DEPENDS ${icu_build_STAMP}
  COMMENT "icu_build target"
)

## Run 'make install'
# set(icu_install_STAMP "${icu_BUILD_DIR}/stamp__icu_install.stamp")
# add_custom_command(OUTPUT ${icu_install_STAMP}
#   COMMAND ${CMAKE_COMMAND} -E env ${ICU_ENV}
#     ${CMAKE_MAKE_PROGRAM} -j ${cmr_BUILD_MULTIPROC_CNT} ${icu_MAKE_SILENT} install
#   COMMAND ${CMAKE_COMMAND} -E touch ${icu_install_STAMP}
#   WORKING_DIRECTORY ${icu_BUILD_DIR}
#   VERBATIM
#   COMMENT "Install ICU library"
#   DEPENDS ${icu_build_STAMP}
# )

# add_custom_target(icu_install
#   DEPENDS ${icu_install_STAMP}
#   COMMENT "icu_install target"
# )

# Run 'make install'
install(CODE "
  set(icu_install_STAMP \"${icu_BUILD_DIR}/stamp__icu_install.stamp\")

  if(NOT EXISTS \${icu_install_STAMP})
    message(STATUS \"Install ICU library\")

    execute_process(
      COMMAND  ${CMAKE_COMMAND}  -E env
        ${CMAKE_MAKE_PROGRAM} -j ${cmr_BUILD_MULTIPROC_CNT} ${icu_MAKE_SILENT} install
      WORKING_DIRECTORY ${icu_BUILD_DIR}
      ENVIRONMENT ${ICU_ENV}
      RESULT_VARIABLE res_icu_install
    )

    if (res_icu_install)
      message(FATAL_ERROR \"Failed install ICU library: \${res_icu_install}\")
    endif()

    execute_process(
      COMMAND ${CMAKE_COMMAND} -E touch \${icu_install_STAMP}
    )
  endif()
")


#-----------------------------------------------------------------------
# Defines for ICUConfig.in.cmake
#-----------------------------------------------------------------------

#  PUBLIC_HEADER DESTINATION include/litehtml
#  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
#  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
#  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
#  FRAMEWORK DESTINATION ${CMAKE_INSTALL_LIBDIR}

set(lib_PFX_SHARED ${CMAKE_SHARED_LIBRARY_PREFIX})
set(lib_SFX_SHARED ${CMAKE_SHARED_LIBRARY_SUFFIX})
set(lib_PFX_STATIC ${CMAKE_STATIC_LIBRARY_PREFIX})
set(lib_SFX_STATIC ${CMAKE_STATIC_LIBRARY_SUFFIX})

if(BUILD_SHARED_LIBS)
  set(lib_PFX ${lib_PFX_SHARED})
  set(lib_SFX ${lib_SFX_SHARED})
  if(is_mac OR is_ios)
    set(lib_SFX ".so")
  endif()
else()
  set(lib_PFX ${lib_PFX_STATIC})
  set(lib_SFX ${lib_SFX_STATIC})
endif()

set(icu_INSTALL_INCLUDE_DIR    "${CMAKE_INSTALL_INCLUDEDIR}")
set(icu_INSTALL_BIN_DIR        "${CMAKE_INSTALL_BINDIR}")
set(icu_INSTALL_LIB_DIR        "${CMAKE_INSTALL_LIBDIR}")
set(icu_INSTALL_PDB_DIR        "${CMAKE_INSTALL_BINDIR}")
set(icu_INSTALL_DATPACKAGE_DIR "${CMAKE_INSTALL_DATAROOTDIR}/icu/${ICU_VERSION}")

set(icu_INSTALL_DLL_DIR
  "$<IF:$<AND:$<BOOL:${is_win}>,$<BOOL:${BUILD_SHARED_LIBS}>>,${icu_INSTALL_BIN_DIR},${icu_INSTALL_LIB_DIR}>"
)

# ICU datpackage (icudt78l.dat)
# icudtl.dat
# TODO: icu_datpackage_FILE_NAME
# TODO: generator expr (if android, android_small, cast, common, ios in
#       <icu/third_party/externals/icu>) for icudtb.dat and icudtl_extra.dat
cmr_get_version_parts(${ICU_VERSION}
  ICU_VERSION_MAJOR ICU_VERSION_MINOR ICU_VERSION_PATCH ICU_VERSION_TWEAK)
set(icu_datpackage_FILE_NAME "icudt${ICU_VERSION_MAJOR}l.dat")

# ICU data
set(icu_data_FILE_NAME "${lib_PFX}icudata${lib_SFX}")
set(icu_data_DLL_LIB_FILE_NAME "icudt.dll.lib")
set(icu_data_DLL_PDB_FILE_NAME "icudt.dll.pdb")

# ICU uc (common)
set(icu_uc_FILE_NAME "${lib_PFX}icuuc${lib_SFX}")
set(icu_uc_DLL_LIB_FILE_NAME "icuuc.dll.lib")
set(icu_uc_DLL_PDB_FILE_NAME "icuuc.dll.pdb")

# ICU i18n
set(icu_i18n_FILE_NAME "${lib_PFX}icui18n${lib_SFX}")
set(icu_i18n_DLL_LIB_FILE_NAME "icuin.dll.lib")
set(icu_i18n_DLL_PDB_FILE_NAME "icuin.dll.pdb")

# ICU io
set(icu_io_FILE_NAME "${lib_PFX}icuio${lib_SFX}")
set(icu_io_DLL_LIB_FILE_NAME "icuio.dll.lib")
set(icu_io_DLL_PDB_FILE_NAME "icuio.dll.pdb")

# ICU tu (toolutil)
set(icu_tu_FILE_NAME "${lib_PFX}icutu${lib_SFX}")
set(icu_tu_DLL_LIB_FILE_NAME "icutu.dll.lib")
set(icu_tu_DLL_PDB_FILE_NAME "icutu.dll.pdb")


#-----------------------------------------------------------------------
# Install ICUConfig.in.cmake
#-----------------------------------------------------------------------

include(CMakePackageConfigHelpers)

set(cmake_gen_config OFF)

configure_package_config_file(
  "${CMAKE_CURRENT_LIST_DIR}/ICUConfig.in.cmake"
  "${icu_BUILD_DIR}/ICUConfig.gen.cmake"
  INSTALL_DESTINATION "${icu_INSTALL_LIB_DIR}/cmake/ICU"
  PATH_VARS
    icu_INSTALL_INCLUDE_DIR
    icu_INSTALL_BIN_DIR
    icu_INSTALL_DLL_DIR
    icu_INSTALL_LIB_DIR
    icu_INSTALL_PDB_DIR
    icu_INSTALL_DATPACKAGE_DIR
)

write_basic_package_version_file(
  "${icu_BUILD_DIR}/ICUConfigVersion.cmake"
  VERSION ${ICU_VERSION}
  COMPATIBILITY "SameFullVersion"
)

file(GENERATE
  OUTPUT "${icu_BUILD_DIR}/ICUConfig.cmake"
  INPUT "${icu_BUILD_DIR}/ICUConfig.gen.cmake"
  NO_SOURCE_PERMISSIONS
  NEWLINE_STYLE UNIX
)

install(
  FILES
    "${icu_BUILD_DIR}/ICUConfig.cmake"
    "${icu_BUILD_DIR}/ICUConfigVersion.cmake"
  DESTINATION "${icu_INSTALL_LIB_DIR}/cmake/ICU"
)


#-----------------------------------------------------------------------
# ICUConfig.in.cmake to build in sorce tree
#-----------------------------------------------------------------------

set(cmake_gen_config ON)

configure_package_config_file(
  "${CMAKE_CURRENT_LIST_DIR}/ICUConfig.in.cmake"
  "${icu_BUILD_DIR}/ICUConfig-config.cmake"
  INSTALL_DESTINATION "${icu_BUILD_DIR}"
  # INSTALL_PREFIX "/root"
  NO_SET_AND_CHECK_MACRO
)

include("${icu_BUILD_DIR}/ICUConfig-config.cmake")


cmake_policy(POP)
