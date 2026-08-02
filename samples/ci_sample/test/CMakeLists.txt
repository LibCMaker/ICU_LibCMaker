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

# Testing with Google Test.
if(BUILD_TESTING)
  cmr_common_test_part()

  if(TARGET ICU::datpackage)
    get_target_property(icu_datpackage_LIB ICU::datpackage IMPORTED_LOCATION)
  endif()

  set_tests_properties(${test_NAME} PROPERTIES
    ENVIRONMENT
      "ICU_DATA=${icu_datpackage_LIB}"
  )

  target_sources(${test_NAME}
    PRIVATE
      ${test_src_DIR}/example_test.cpp
  )

  # ICU
  target_link_libraries(${test_NAME} PRIVATE ICU::io ICU::i18n ICU::uc ICU::data)
endif()
