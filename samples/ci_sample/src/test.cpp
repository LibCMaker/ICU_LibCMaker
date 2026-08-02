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

//
// c++ test.cpp -o test -std=c++0x `pkg-config --libs --cflags icu-uc icu-io` -I/usr/include/x86_64-linux-gnu  -licuio -licui18n -licuuc -licudata 
//

#include <stdio.h>
#include <unicode/ucol.h>
#include <unicode/usearch.h>
#include <unicode/ustring.h>

int main()
{
    printf("Hello CPP!\n");
    
    UErrorCode err = U_ZERO_ERROR;
    UCollator *collator = ucol_open("da_DK", &err);
    // UCollator *collator = ucol_open("en_US", &err);
    // UCollator *collator = ucol_open("nn-NO", &err);
    
    if (!U_SUCCESS(err))
    {
        printf("Error open collator %d\n", err);
        return 1;
    }

    UColAttributeValue attributeValue = ucol_getAttribute(collator, UCOL_STRENGTH, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error get attribute search %d\n", err);
        ucol_close(collator);
        return 4;
    }
    
    printf("attribut value of strength = %d\n", attributeValue);
    
    attributeValue = ucol_getAttribute(collator, UCOL_CASE_LEVEL, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error get case attribute search %d\n", err);
        ucol_close(collator);
        return 9;
    }
    printf("attribut original value of casing = %d\n", attributeValue);    
   
    // char *source = (char *) "Is AE or ae the same as \x00C6 or \x00E6";
    char *source = (char *) "This is a fox";
    char *target = (char *) "Fox";
    // char *source = (char *) "This is a fox\r\n";
    // char *source = (char *) "\r\n";
    // char *target = (char *) "\r";
    // char *source = (char *) "Hello \x00C6 \x00E6";
    // char *target = (char *) "ae";
    
    UChar usource[100];
    UChar utarget[100];
    
    // u_uastrncpy(usource, source, 5);
    // u_uastrncpy(utarget, target, 1);  
    u_uastrcpy(usource, source);
    u_uastrcpy(utarget, target);  
    
    ucol_setAttribute(collator, UCOL_STRENGTH, UCOL_PRIMARY, &err);
    // ucol_setAttribute(collator, UCOL_STRENGTH, UCOL_SECONDARY, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error set strength attribute search %d\n", err);
        ucol_close(collator);
        return 5;
    }    

    attributeValue = ucol_getAttribute(collator, UCOL_CASE_LEVEL, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error get case attribute search %d\n", err);
        ucol_close(collator);
        return 10;
    }
    printf("attribut new value of casing after setting stength level= %d\n", attributeValue);    

    ucol_setAttribute(collator, UCOL_CASE_LEVEL, UCOL_ON, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error set case level attribute search %d\n", err);
        ucol_close(collator);
        return 6;
    }    
    
    attributeValue = ucol_getAttribute(collator, UCOL_STRENGTH, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error get attribute search %d\n", err);
        ucol_close(collator);
        return 7;
    }
    printf("attribut new value of strength = %d\n", attributeValue);   
    
    attributeValue = ucol_getAttribute(collator, UCOL_CASE_LEVEL, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error get case attribute search %d\n", err);
        ucol_close(collator);
        return 8;
    }
    printf("attribut new value of casing = %d\n", attributeValue);    
    
    // ucol_setAttribute(collator, UCOL_NORMALIZATION_MODE, UCOL_ON, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error set Normalization attribute search %d\n", err);
        ucol_close(collator);
        return 13;
    }    
    
    UStringSearch *search = usearch_openFromCollator(utarget, -1, usource, -1, collator, NULL, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error open search %d\n", err);
        ucol_close(collator);
        return 2;
    }
    
    int32_t result = usearch_first(search, &err);
    if (!U_SUCCESS(err))
    {
        printf("Error search %d\n", err);
        usearch_close(search);
        ucol_close(collator);
        return 3;
    }
    
    printf("found '%s' in '%s' in position: %d\n", target, source, result);
    
 
    UChar unewLine[4];
    uint8_t sortKey[130];
    u_uastrcpy(unewLine, "\x00E6");
    int32_t sortKeyLength = ucol_getSortKey(collator, unewLine, -1, sortKey, 30);
    
    if (sortKeyLength == 0)
    {
        printf("Error, couldn't get the sort key for 00E6 character");
        usearch_close(search);
        ucol_close(collator);
        return 11;
    }
    
    printf("sortkey for 00E6 character = ");
    for (int32_t i=0; i<sortKeyLength; i++)
    {
        printf("%d, ", (int32_t) sortKey[i]);
    }
    printf("\n");
    
    u_uastrcpy(unewLine, "ae");
    sortKeyLength = ucol_getSortKey(collator, unewLine, -1, sortKey, 130);
    
    if (sortKeyLength == 0)
    {
        printf("Error, couldn't get the sort key for the phrase has a new line character");
        usearch_close(search);
        ucol_close(collator);
        return 12;
    }
    
    printf("sortkey for ae = ");
    for (int32_t i=0; i<sortKeyLength; i++)
    {
        printf("%d, ", (int32_t) sortKey[i]);
    }
    printf("\n");
    
    
    UChar uae[10];    
    UChar uaeLigature[10];    
    u_uastrcpy(uae, "ae");
    u_uastrcpy(uaeLigature, "\x00E6");
    
    UCollationResult ucolres = ucol_strcoll(collator, uae, -1, uaeLigature, -1);
    switch (ucolres)
    {
        case UCOL_EQUAL:
            printf("%ws is EQUAL to %ws\n", uae, uaeLigature);
            break;

        case UCOL_GREATER:
            printf("%ws is GREATER to %ws\n", uae, uaeLigature);
            break;
            
        case UCOL_LESS:
            printf("%ws is LESS to %ws\n", uae, uaeLigature);
            break;
    }

    usearch_close(search);
    ucol_close(collator);
    return 0;
}
