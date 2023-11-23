
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

extern void *INT,*INT32,*CHAR,*BOOL,*REAL,*REAL32,*__STRING__,*__ARRAY__;
extern Int small_integers[],static_characters[];

/* 2 for callgraph profiling. In this case, we need to add a pointer argument
 * to thunks pointing at the current cost centre. */
#ifndef NO_PROFILE_GRAPH
extern int profile_type;
extern void *profile_current_cost_centre;
#endif

/*inline*/
static void copy (Int *dest_p,Int *source_p,Int n_words)
{
	Int i;

	for (i=0; i<n_words; ++i)
		dest_p[i]=source_p[i];
}

Int *copy_string_to_graph (Int *string_p,void *begin_free_heap,void *end_free_heap,Int **last_heap_pa)
{
#ifndef NO_PROFILE_GRAPH
	if (profile_type==2){
# define PROFILE_GRAPH
# include "copy_string_to_graph_implementation.c"
# undef PROFILE_GRAPH
	} else
#endif
	{
#include "copy_string_to_graph_implementation.c"
	}
}

void remove_forwarding_pointers_from_string (Int *string_p,Int *end_forwarding_pointers)
{
	string_p+=2;

	while (string_p<end_forwarding_pointers){
		Int forwarding_pointer;
			
		forwarding_pointer=*string_p;
		if (!(forwarding_pointer & 1)){
			Int desc;
			
			desc=*(Int*)forwarding_pointer;
#ifdef USE_DESC_RELATIVE_TO_ARRAY
			*string_p=desc-(Int)&__ARRAY__;
#else
			*string_p=desc;
#endif
			if (desc & 2){
				unsigned Int arity;
				
				arity=((unsigned short *)desc)[-1];
				if (arity==0){
					if (desc==(Int)&INT+2 || desc==(Int)&CHAR+2 || desc==(Int)&BOOL+2
#if ARCH_64
						|| desc==(Int)&REAL+2
#endif
					){
						string_p+=2;
#if ! ARCH_64
					} else if (desc==(Int)&REAL+2){
						string_p+=3;
#endif
					} else if (desc==(Int)&__STRING__+2){
						unsigned Int length,n_words;
							
						length=string_p[1];
						string_p+=2;
#if ARCH_64
						n_words=(length+7)>>3;
#else
						n_words=(length+3)>>2;
#endif
						string_p+=n_words;
					} else if (desc==(Int)&__ARRAY__+2){
						Int array_size,elem_desc;

						array_size=string_p[1];
						elem_desc=string_p[2];
						string_p+=3;

						if (elem_desc!=0){
#if defined (USE_DESC_RELATIVE_TO_ARRAY)
							elem_desc+=(Int)&__ARRAY__;
#endif

							if (elem_desc==(Int)&INT+2
#if ARCH_64
								|| elem_desc==(Int)&REAL+2
#else
								|| elem_desc==(Int)&INT32+2
								|| elem_desc==(Int)&REAL32+2
#endif
							){
								string_p+=array_size;
#if ARCH_64
							} else if (elem_desc==(Int)&INT32+2 || elem_desc==(Int)&REAL32+2){
								array_size=(array_size+1)>>1;
								string_p+=array_size;
#else
							} else if (elem_desc==(Int)&REAL+2){
								array_size<<=1;
								string_p+=array_size;
#endif
							} else if (elem_desc==(Int)&BOOL+2){
#if ARCH_64
								array_size=(array_size+7)>>3;
#else
								array_size=(array_size+3)>>2;
#endif
								string_p+=array_size;
							} else {
								Int n_field_pointers,n_non_field_pointers,field_size;

								n_field_pointers=*(unsigned short *)elem_desc;
								field_size=((unsigned short *)elem_desc)[-1]-(Int)256;
								n_non_field_pointers=field_size-n_field_pointers;

								string_p+=n_non_field_pointers*array_size;
							}
						}
					} else {
						++string_p;
					}
				} else {
					++string_p;
					if (arity>=256){
						Int n_pointers,n_non_pointers;

						n_pointers=*(unsigned short*)desc;
						arity-=256;
						n_non_pointers=arity-n_pointers;
						string_p+=n_non_pointers;
					}
				}
			} else {
				Int arity;

				arity=((int*)desc)[-1];
				++string_p;
				if (arity>=256){
					Int n_non_pointers;
					
					n_non_pointers=arity>>8;
					string_p+=n_non_pointers;
				}
			}
		} else {
			++string_p;
		}
	}
}
