
#include <stdlib.h>

#ifdef _WIN64
# define Int __int64
# define ARCH_64 1
#else
# if defined (MACH_O64) || defined (LINUX64)
#  define Int long long
#  define ARCH_64 1
# else
#  define Int int
#  define ARCH_64 0
# endif
# if !(defined (LINUX32) || defined (LINUX64))
#  define __STRING__ _STRING__
#  define __ARRAY__ _ARRAY__
# endif
#endif

#if defined (MACH_O64) || defined (PIC)
// Use positions relative to _ARRAY_ for address space layout randomization systems.
#  define USE_DESC_RELATIVE_TO_ARRAY 1
#endif

int is_using_desc_relative_to_array (void)
{
#ifdef USE_DESC_RELATIVE_TO_ARRAY
	return 1;
#else
	return 0;
#endif
}

extern void *INT,*INT32,*CHAR,*BOOL,*REAL,*REAL32,*__STRING__,*__ARRAY__;

/* 2 for callgraph profiling. When this is turned on, we need to ignore the
 * last part of thunks, as it is used for the saved cost centre stack. */
#ifndef NO_PROFILE_GRAPH
extern int profile_type;
#endif

/*inline*/
static void copy (Int *dest_p,Int *source_p,Int n_words)
{
	Int i;

	for (i=0; i<n_words; ++i)
		dest_p[i]=source_p[i];
}

Int *copy_graph_to_string (Int *node_p,void *begin_free_heap,void *end_free_heap
#ifdef THREAD
							,void *begin_heap,unsigned Int heap_size
#endif
							)
{
#ifndef NO_PROFILE_GRAPH
	if (profile_type==2){
# define PROFILE_GRAPH
# include "copy_graph_to_string_implementation.c"
# undef PROFILE_GRAPH
	} else
#endif
	{
#include "copy_graph_to_string_implementation.c"
	}
}

void remove_forwarding_pointers_from_graph (Int *node_p,Int **stack_end)
{
#ifndef NO_PROFILE_GRAPH
	if (profile_type==2){
# define PROFILE_GRAPH
# include "remove_forwarding_pointers_from_graph_implementation.c"
# undef PROFILE_GRAPH
	} else
#endif
	{
#include "remove_forwarding_pointers_from_graph_implementation.c"
	}
}
