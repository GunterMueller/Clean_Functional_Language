#include <memory.h>
#include <windows.h>

void abort()
{
	ExitProcess (1);
}

void perror(const char *message)
{
	MessageBox (NULL, message, "fatal error", MB_ICONERROR);
}

void *my_memcpy( void *dest, const void *src, size_t count )
// it is assumed, that LocalAlloc only allocates word aligned memory
{
	size_t i;
	count = count>>2;
	for(i=0; i<count; i++)
		((int*) dest)[i] = ((int*) src)[i];
	return dest;
}

void *malloc (size_t size)
{
	return LocalAlloc(LMEM_FIXED, size);
}

void *realloc(void *original, size_t new_size)
{
	char *new_mem;
	new_mem	= LocalAlloc(LMEM_FIXED, new_size);
	if (!new_mem) {
		perror("not enough memory");
		abort();
		};
	LocalFree(original);
	return new_mem;
}


void free (void *mem_ptr)
{
	LocalFree(mem_ptr);
}
