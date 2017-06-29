/*
 * Copyright 2014, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(NICTA_GPL)
 */

#ifndef _STROPS_H_
#define _STROPS_H_

#include <types.h>

size_t strlen(const char *str);
int strcmp(const char *a, const char *b);
int strncmp(const char* s1, const char* s2, int n);
void *memset(void *s, int c, size_t n);
void *memcpy(void *dest, const void *src, size_t n);

#endif /* _STROPS_H_ */
