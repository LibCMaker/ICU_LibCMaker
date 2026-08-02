/*****************************************************************************
 * Project:  LibCMaker
 * Purpose:  A CMake build scripts for build libraries with CMake
 * Author:   NikitaFeodonit, nfeodonit@yandex.com
 *****************************************************************************
 *   Copyright (c) 2017-2026 NikitaFeodonit
 *
 *    This file is part of the LibCMaker project.
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published
 *    by the Free Software Foundation, either version 3 of the License,
 *    or (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *    See the GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program. If not, see <http://www.gnu.org/licenses/>.
 ****************************************************************************/

// The code is based on the code from "test.cpp"
// https://gist.github.com/tarekgh/71ad02888da20ce33b776806ee7ca9cb

// This code allows to check the existence of ICU .dat package file,
// icudtXXx.dat, icudt<version><flag>.dat

#include <unicode/ucol.h>
#include <unicode/usearch.h>
#include <unicode/ustring.h>

#include "gtest/gtest.h"

TEST(Examle, test) {
  UErrorCode err = U_ZERO_ERROR;

  UCollator *collator = ucol_open("da_DK", &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error open collator " << err;

  UColAttributeValue attributeValue = ucol_getAttribute(collator, UCOL_STRENGTH, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error get attribute search " << err;
  ASSERT_EQ(2, attributeValue);

  attributeValue = ucol_getAttribute(collator, UCOL_CASE_LEVEL, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error get case attribute search " << err;
  ASSERT_EQ(16, attributeValue);

  char *source = (char *) "This is a fox";
  char *target = (char *) "Fox";

  UChar usource[100];
  UChar utarget[100];

  u_uastrcpy(usource, source);
  u_uastrcpy(utarget, target);

  ucol_setAttribute(collator, UCOL_STRENGTH, UCOL_PRIMARY, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error set strength attribute search " << err;

  attributeValue = ucol_getAttribute(collator, UCOL_CASE_LEVEL, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error get case attribute search " << err;
  ASSERT_EQ(16, attributeValue);

  ucol_setAttribute(collator, UCOL_CASE_LEVEL, UCOL_ON, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error set case level attribute search " << err;

  attributeValue = ucol_getAttribute(collator, UCOL_STRENGTH, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error get attribute search " << err;
  ASSERT_EQ(0, attributeValue);

  attributeValue = ucol_getAttribute(collator, UCOL_CASE_LEVEL, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error get case attribute search " << err;
  ASSERT_EQ(17, attributeValue);

  UStringSearch *search = usearch_openFromCollator(utarget, -1, usource, -1, collator, NULL, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error open search " << err;

  int32_t result = usearch_first(search, &err);
  ASSERT_TRUE(U_SUCCESS(err)) << "Error search " << err;
  ASSERT_STREQ("Fox", target);
  ASSERT_STREQ("This is a fox", source);
  ASSERT_EQ(10, result);

  UChar unewLine[4];
  uint8_t sortKey[130];
  u_uastrcpy(unewLine, "\x00E6");

  int32_t sortKeyLength = ucol_getSortKey(collator, unewLine, -1, sortKey, 30);
  ASSERT_EQ(5, sortKeyLength) << "Error, couldn't get the sort key for 00E6 character";
  ASSERT_EQ(255, (int32_t) sortKey[0]);
  ASSERT_EQ(253, (int32_t) sortKey[1]);
  ASSERT_EQ(1, (int32_t) sortKey[2]);
  ASSERT_EQ(48, (int32_t) sortKey[3]);
  ASSERT_EQ(0, (int32_t) sortKey[4]);

  u_uastrcpy(unewLine, "ae");

  sortKeyLength = ucol_getSortKey(collator, unewLine, -1, sortKey, 130);
  ASSERT_EQ(5, sortKeyLength) << "Error, couldn't get the sort key for the phrase has a new line character";
  ASSERT_EQ(43, (int32_t) sortKey[0]);
  ASSERT_EQ(51, (int32_t) sortKey[1]);
  ASSERT_EQ(1, (int32_t) sortKey[2]);
  ASSERT_EQ(64, (int32_t) sortKey[3]);
  ASSERT_EQ(0, (int32_t) sortKey[4]);

  usearch_close(search);
  ucol_close(collator);
}
