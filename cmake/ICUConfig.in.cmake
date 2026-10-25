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

@PACKAGE_INIT@


#if(cmake_gen_config)
if(@cmake_gen_config@)
  macro(set_and_check _var _file)
    set(${_var} "${_file}")
  endmacro()
endif()


#
# CMakePackageConfigHelpers
# -------------------------------------



#-----------------------------------------------------------------------
# Find external libraries and set public defines
#-----------------------------------------------------------------------

set(lib_PFX "@lib_PFX@")
set(lib_SFX "@lib_SFX@")

#if(cmake_gen_config)
if(@cmake_gen_config@)

  set(icu_uc_INCLUDE_DIR   "${icu_SRC_DIR}/source/common")
  set(icu_i18n_INCLUDE_DIR "${icu_SRC_DIR}/source/i18n")
  set(icu_io_INCLUDE_DIR   "${icu_SRC_DIR}/source/io")

  set(icu_BIN_DIR "${icu_BUILD_DIR}/bin")
  set(icu_DLL_DIR "${icu_BUILD_DIR}/lib")  # TODO: icu_DLL_DIR
  set(icu_LIB_DIR "${icu_BUILD_DIR}/lib")
  set(icu_PDB_DIR "${icu_BUILD_DIR}/bin")

  set(icu_DATPACKAGE_DIR "${icu_BUILD_DIR}/data/out")
  set(icu_data_DIR       "${icu_BUILD_DIR}/stubdata")

else()
  set(icu_INCLUDE_DIR "@PACKAGE_icu_INSTALL_INCLUDE_DIR@")

  set(icu_uc_INCLUDE_DIR   "${icu_INCLUDE_DIR}")
  set(icu_i18n_INCLUDE_DIR "${icu_INCLUDE_DIR}")
  set(icu_io_INCLUDE_DIR   "${icu_INCLUDE_DIR}")

  set(icu_BIN_DIR "@PACKAGE_icu_INSTALL_BIN_DIR@")
  set(icu_DLL_DIR "@PACKAGE_icu_INSTALL_DLL_DIR@")
  set(icu_LIB_DIR "@PACKAGE_icu_INSTALL_LIB_DIR@")
  set(icu_PDB_DIR "@PACKAGE_icu_INSTALL_PDB_DIR@")

  set(icu_DATPACKAGE_DIR "@PACKAGE_icu_INSTALL_DATPACKAGE_DIR@")
  set(icu_data_DIR       "${icu_LIB_DIR}")  # TODO: icu_data_DIR
endif()


macro(icu_set_target_properties name)
  #if(NOT BUILD_SHARED_LIBS)
  if(NOT @BUILD_SHARED_LIBS@)
    set_target_properties(${name} PROPERTIES
      IMPORTED_NO_SONAME ON
      INTERFACE_COMPILE_FEATURES "cxx_std_17"
      IMPORTED_LINK_INTERFACE_LANGUAGES "CXX"
    )
  endif()
endmacro()


#if(BUILD_SHARED_LIBS)
if(@BUILD_SHARED_LIBS@)
  set(lib_type SHARED)
else()
  set(lib_type STATIC)
endif()


#-----------------------------------------------------------------------
# ICU::datpackage (icudtXXx.dat)
#-----------------------------------------------------------------------

# set_and_check(icu_datpackage_LIB "${icu_DATPACKAGE_DIR}/@icu_datpackage_FILE_NAME@")
add_library(ICU::datpackage UNKNOWN IMPORTED)
set_target_properties(ICU::datpackage PROPERTIES
  IMPORTED_LOCATION "${icu_datpackage_LIB}"
  IMPORTED_NO_SONAME ON
)
#if(cmake_gen_config)
if(@cmake_gen_config@)
  add_dependencies(ICU::datpackage icu_build)
endif()


#-----------------------------------------------------------------------
# add_icu_library
#-----------------------------------------------------------------------

macro(add_icu_library name file_name dll_lib_file_name)
  if(${name} STREQUAL "data")
    set(__DLL_DIR "${icu_data_DIR}")
    set(__LIB_DIR "${icu_data_DIR}")
  else()
    set(__DLL_DIR "${icu_DLL_DIR}")
    set(__LIB_DIR "${icu_LIB_DIR}")
  endif()


  add_library(ICU::${name} ${lib_type} IMPORTED)

  # ICU is C++ library.
  set_target_properties(ICU::${name} PROPERTIES LINKER_LANGUAGE CXX)

  set_property(TARGET ICU::${name} APPEND PROPERTY
    INTERFACE_COMPILE_DEFINITIONS
      "U_USING_ICU_NAMESPACE=0"
      "U_DISABLE_VERSION_SUFFIX=1"
      "U_DEFAULT_SHOW_DRAFT=0"
      "U_DISABLE_RENAMING=1"
      "U_ENABLE_TRACING=0"
  )
  #if(NOT BUILD_SHARED_LIBS)
  if(NOT @BUILD_SHARED_LIBS@)
    set_property(TARGET ICU::${name} APPEND PROPERTY
      INTERFACE_COMPILE_DEFINITIONS
        "U_STATIC_IMPLEMENTATION"
    )
  endif()
  #if(is_win)
  if(@is_win@)
    set_property(TARGET ICU::${name} APPEND PROPERTY
      INTERFACE_COMPILE_DEFINITIONS "U_NOEXCEPT="
    )
  endif()

  if((NOT ${name} STREQUAL "data") AND (NOT ${name} STREQUAL "tu"))
    set_property(TARGET ICU::${name} APPEND PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES "${icu_${name}_INCLUDE_DIR}"
    )
  endif()

  set_and_check(icu_${name}_LIB "${__DLL_DIR}/${file_name}")
  set_target_properties(ICU::${name} PROPERTIES
    IMPORTED_LOCATION "${icu_${name}_LIB}"
  )

  #if(is_win AND BUILD_SHARED_LIBS)
  if(@is_win@ AND @BUILD_SHARED_LIBS@)
    set_and_check(icu_${name}_DLL_LIB "${__LIB_DIR}/${dll_lib_file_name}")
    set_target_properties(ICU::${name} PROPERTIES
      IMPORTED_IMPLIB "${icu_${name}_DLL_LIB}"
    )
  endif()

  # TODO: PDB


  unset(__DLL_DIR)
  unset(__LIB_DIR)
endmacro()


#-----------------------------------------------------------------------
# ICU::libs
#-----------------------------------------------------------------------

add_icu_library(data @icu_data_FILE_NAME@ @icu_data_DLL_LIB_FILE_NAME@)
add_icu_library(uc @icu_uc_FILE_NAME@ @icu_uc_DLL_LIB_FILE_NAME@)
add_icu_library(i18n @icu_i18n_FILE_NAME@ @icu_i18n_DLL_LIB_FILE_NAME@)
add_icu_library(io @icu_io_FILE_NAME@ @icu_io_DLL_LIB_FILE_NAME@)
add_icu_library(tu @icu_tu_FILE_NAME@ @icu_tu_DLL_LIB_FILE_NAME@)

add_dependencies(ICU::data ICU::datpackage)

# TODO: DEFAULT_LIBS = -lpthread -lm
set_property(TARGET ICU::uc APPEND PROPERTY
  INTERFACE_LINK_LIBRARIES
    ICU::data
)

set_property(TARGET ICU::i18n APPEND PROPERTY
  INTERFACE_LINK_LIBRARIES
    ICU::uc
)

set_property(TARGET ICU::io APPEND PROPERTY
  INTERFACE_LINK_LIBRARIES
    ICU::i18n ICU::uc
)

set_property(TARGET ICU::tu APPEND PROPERTY
  INTERFACE_LINK_LIBRARIES
    ICU::i18n ICU::uc
)



# -------------------------------------
# CMakePackageConfigHelpers
#

check_required_components("ICU")
