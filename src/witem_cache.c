/*
 * Copyright (c) 2011, Joakim Johansson <jocke@tbricks.com>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include "private.h"

/*
 * Work item cache modelled on libdispatch continuation implementation
 */

pthread_key_t witem_cache_key;

#if WITEM_CACHE_DISABLE    

struct work *
witem_alloc_from_heap(void)
{
	struct work *witem;
    
	while (!(witem = fastpath(malloc(ROUND_UP_TO_CACHELINE_SIZE(sizeof(*witem)))))) {
		sleep(1);
	}
    
	return witem;
}

struct work *
witem_alloc_cacheonly()
{
	return NULL;
}

void 
witem_free(struct work *wi)
{
    free(wi);
}

void
witem_cache_cleanup(void *value)
{
}

#else

struct work *
witem_alloc_from_heap(void)
{
	struct work *witem;
    
	while (!(witem = fastpath(malloc(ROUND_UP_TO_CACHELINE_SIZE(sizeof(*witem)))))) {
		sleep(1);
	}
    
	return witem;
}

struct work *
witem_alloc_cacheonly()
{
    struct work *wi = fastpath(pthread_getspecific(witem_cache_key));
	if (wi) {
		pthread_setspecific(witem_cache_key, wi->wi_next);
	}
	return wi;
}

void 
witem_free(struct work *wi)
{
	struct work *prev_wi = pthread_getspecific(witem_cache_key);
	wi->wi_next = prev_wi;
	pthread_setspecific(witem_cache_key, wi);
}

void
witem_cache_cleanup(void *value)
{
	struct work *wi, *next_wi = value;
    
	while ((wi = next_wi)) {
		next_wi = wi->wi_next;
		free(wi);
	}
}
#endif
