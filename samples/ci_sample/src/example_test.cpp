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

// The code is based on the code from
// <icu-source>/icu/source/samples/date.c

/*
*************************************************************************
*   © 2016 and later: Unicode, Inc. and others.
*   License & terms of use: http://www.unicode.org/copyright.html#License
*************************************************************************
***********************************************************************
*   Copyright (C) 1998-2012, International Business Machines
*   Corporation and others.  All Rights Reserved.
**********************************************************************
*
* File date.c
*
* Modification History:
*
*   Date        Name        Description
*   06/11/99    stephen     Creation.
*   06/16/99    stephen     Modified to use uprint.
*   08/11/11    srl         added Parse and milli/second in/out
*******************************************************************************
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "unicode/uclean.h"
#include "unicode/ustring.h"
#include "unicode/utypes.h"

#include "unicode/ucal.h"
#include "unicode/ucnv.h"
#include "unicode/udat.h"

#include "uprint.h"

#include "gtest/gtest.h"

#if UCONFIG_NO_FORMATTING || UCONFIG_NO_CONVERSION

TEST(Examle, test) {
  printf("%s: Sorry, UCONFIG_NO_FORMATTING or UCONFIG_NO_CONVERSION was turned "
         "on (see uconfig.h). No formatting can be done. \n",
         argv[0]);
  EXPECT_TRUE(false);
}
#else

/* Protos */
static void date(UDate when, const UChar *tz, UDateFormatStyle style,
                 const char *format, UErrorCode *status);
static UDate getWhen(const char *millis, const char *seconds,
                     const char *format, UDateFormatStyle style,
                     const char *parse, const UChar *tz, UErrorCode *status);

UConverter *cnv = NULL;

/* The version of date */
#define DATE_VERSION "1.0"

/* "GMT" */
static const UChar GMT_ID[] = {0x0047, 0x004d, 0x0054, 0x0000};

#define FORMAT_MILLIS "%"
#define FORMAT_SECONDS "%%"

TEST(Examle, test) {
  const UChar *tz = 0;
  UDateFormatStyle style = UDAT_DEFAULT;
  UErrorCode status = U_ZERO_ERROR;
  const char *format = NULL;
  char *parse = NULL;
  char *seconds = NULL;
  char *millis = NULL;
  UDate when;

  /* get the 'when' (or now) */
  when = getWhen(millis, seconds, format, style, parse, tz, &status);
  if (parse != NULL) {
    format = FORMAT_MILLIS; /* output in millis */
  }

  /* print the date */
  date(when, tz, style, format, &status);

  ucnv_close(cnv);

  u_cleanup();
  EXPECT_FALSE(U_FAILURE(status));
}

static int32_t charsToUCharsDefault(UChar *uchars, int32_t ucharsSize,
                                    const char *chars, int32_t charsSize,
                                    UErrorCode *status) {
  int32_t len = -1;
  if (U_FAILURE(*status))
    return len;
  if (cnv == NULL) {
    cnv = ucnv_open(NULL, status);
  }
  if (cnv && U_SUCCESS(*status)) {
    len = ucnv_toUChars(cnv, uchars, ucharsSize, chars, charsSize, status);
  }
  return len;
}

/* Format the date */
static void date(UDate when, const UChar *tz, UDateFormatStyle style,
                 const char *format, UErrorCode *status) {
  UChar *s = 0;
  int32_t len = 0;
  UDateFormat *fmt;
  UChar uFormat[100];

  if (U_FAILURE(*status))
    return;

  if (format != NULL) {
    if (!strcmp(format, FORMAT_MILLIS)) {
      printf("%.0f\n", when);
      return;
    } else if (!strcmp(format, FORMAT_SECONDS)) {
      printf("%.3f\n", when / 1000.0);
      return;
    }
  }

  fmt = udat_open(style, style, 0, tz, -1, NULL, 0, status);
  if (format != NULL) {
    charsToUCharsDefault(uFormat, sizeof(uFormat) / sizeof(uFormat[0]), format,
                         -1, status);
    udat_applyPattern(fmt, FALSE, uFormat, -1);
  }
  len = udat_format(fmt, when, 0, len, 0, status);
  if (*status == U_BUFFER_OVERFLOW_ERROR) {
    *status = U_ZERO_ERROR;
    s = (UChar *)malloc(sizeof(UChar) * (len + 1));
    if (s == 0)
      goto finish;
    udat_format(fmt, when, s, len + 1, 0, status);
  }
  if (U_FAILURE(*status))
    goto finish;

  /* print the date string */
  uprint(s, stdout, status);

  /* print a trailing newline */
  printf("\n");

finish:
  if (U_FAILURE(*status)) {
    fprintf(stderr, "Error in Print: %s\n", u_errorName(*status));
  }
  udat_close(fmt);
  free(s);
}

static UDate getWhen(const char *millis, const char *seconds,
                     const char *format, UDateFormatStyle style,
                     const char *parse, const UChar *tz, UErrorCode *status) {
  UDateFormat *fmt = NULL;
  UChar uFormat[100];
  UChar uParse[256];
  UDate when = 0;
  int32_t parsepos = 0;

  if (millis != NULL) {
    sscanf(millis, "%lf", &when);
    return when;
  } else if (seconds != NULL) {
    sscanf(seconds, "%lf", &when);
    return when * 1000.0;
  }

  if (parse != NULL) {
    if (format != NULL) {
      if (!strcmp(format, FORMAT_MILLIS)) {
        sscanf(parse, "%lf", &when);
        return when;
      } else if (!strcmp(format, FORMAT_SECONDS)) {
        sscanf(parse, "%lf", &when);
        return when * 1000.0;
      }
    }

    fmt = udat_open(style, style, 0, tz, -1, NULL, 0, status);
    if (format != NULL) {
      charsToUCharsDefault(uFormat, sizeof(uFormat) / sizeof(uFormat[0]),
                           format, -1, status);
      udat_applyPattern(fmt, FALSE, uFormat, -1);
    }

    charsToUCharsDefault(uParse, sizeof(uParse) / sizeof(uParse[0]), parse, -1,
                         status);
    when = udat_parse(fmt, uParse, -1, &parsepos, status);
    if (U_FAILURE(*status)) {
      fprintf(stderr, "Error in Parse: %s\n", u_errorName(*status));
      if (parsepos > 0 && parsepos <= (int32_t)strlen(parse)) {
        fprintf(stderr,
                "ERR>\"%s\" @%d\n"
                "ERR> %*s^\n",
                parse, parsepos, parsepos, "");
      }
    }

    udat_close(fmt);
    return when;
  } else {
    return ucal_getNow();
  }
}

#endif
