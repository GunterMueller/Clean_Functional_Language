
#include <stddef.h>
#include "compiledefines.h"
#include "clib_functions.h"

#undef _WINDOWS_
#include <windows.h>

#ifdef DEFINE_MEMSET
void *memset (void *d,int c,size_t n)
{
	unsigned char *d_p;
	
	d_p=d;
	/* cl recognizes memset, causing infinite recursion, unrolling by 2 prevents this */
	if ((n & 1)!=0){
		*d_p++ = c;
		--n;
	}
	while (n!=0){
		*d_p++ = c;
		*d_p++ = c;
		n-=2;
	}

	return d;
}
#endif

#ifdef DEFINE_MEMCPY
void *memcpy (void *d,const void *s,size_t n)
#else
void *clean_compiler_memcpy (void *d,const void *s,size_t n)
#endif
{
	unsigned char *d_p;
	const unsigned char *s_p;
	
	d_p=d;
	s_p=s;
	while (n!=0){
		*d_p++ = *s_p++;
		--n;
	}

	return d;
}

char *clean_compiler_strcpy (char *s1,const char *s2)
{
	char *r;

	r=s1;

	while ((*s1=*s2)!='\0'){
		++s1;
		++s2;
	}

	return r;
}

char *clean_compiler_strcat (char *s1,const char *s2)
{
	char *r;

	r=s1;

	while (*s1!='\0')
		++s1;
	while ((*s1=*s2)!='\0'){
		++s1;
		++s2;
	}

	return r;
}

char *clean_compiler_strncpy (char *dest, const char *src, size_t n)
{
	size_t i;

	for (i = 0; i < n && src[i] != '\0'; ++i)
		dest[i] = src[i];

	for ( ; i < n; ++i)
		dest[i] = '\0';

	return dest;
}

int clean_compiler_strcmp (const char *s1_a,const char *s2_a)
{
	unsigned char *s1,*s2;
	
	s1=(unsigned char*)s1_a;
	s2=(unsigned char*)s2_a;

	while (*s1!='\0' && *s1==*s2){
		++s1;
		++s2;
	}

	return *s1 - *s2;
}

int clean_compiler_strncmp (const char *s1_a,const char *s2_a,size_t n)
{
	unsigned char *s1,*s2;
	
	s1=(unsigned char*)s1_a;
	s2=(unsigned char*)s2_a;

	while (n!=0 && *s1!='\0' && *s1==*s2){
		++s1;
		++s2;
		--n;
	}

	if (n==0)
		return 0;

	return *s1 - *s2;
}

size_t clean_compiler_strlen (const char *s)
{
	const char *begin_s;
	
	begin_s=s;
	while (*s!='\0')
		++s;
	return s-begin_s;
}
  
void *malloc (size_t n)
{
	return HeapAlloc (GetProcessHeap(),0,n);
}

void free (void *p)
{
	HeapFree (GetProcessHeap(),0,p);
}

void *realloc (void *p, size_t n)
{
	return HeapReAlloc (GetProcessHeap(),0,p,n);
}

void exit (int n)
{
	ExitProcess (n);
}
