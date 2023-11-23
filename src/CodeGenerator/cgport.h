
#define FINALIZERS
#define NEW_APPLY

#ifdef _WIN64
# define G_AI64
#endif
#ifdef G_AI64
# define G_A64
#elif defined (__GNUC__) && defined (__SIZEOF_POINTER__)
# if __SIZEOF_POINTER__==8
#  define G_A64
# endif
#endif

#if defined (__MWERKS__) || defined (__MRC__)
# define POWER
# ifdef __cplusplus
#  include "cgrenameglobals.h"
# elif !defined (MAKE_MPW_TOOL)
#  define G_POWER
# endif
#endif

#if defined (I486) || defined (ARM) || defined (G_POWER) || defined (sparc)
# define NEW_DESCRIPTORS
#endif

#if 0 || defined (MACH_O)
#define ALIGN_C_CALLS
#endif

#if defined (G_POWER) || defined (_WINDOWS_) || defined (LINUX_ELF) || defined (sparc)
# define FUNCTION_LEVEL_LINKING
#endif
                                                                                                                        
#ifdef THINK_C
#	define ANSI_C
#	define WORD int
#	define UWORD unsigned int
#else
#	define WORD short
#	define UWORD unsigned short
#endif

#ifdef GNU_C
#	define ANSI_C
#	undef mc68020
# ifdef SUN_C
#	define VARIABLE_ARRAY_SIZE 1
# else
#	define VARIABLE_ARRAY_SIZE 0
# endif
#else
# if defined (POWER) && !defined (__MRC__) && !defined (__MWERKS__)
#	define VARIABLE_ARRAY_SIZE 0
# else
#	define VARIABLE_ARRAY_SIZE
# endif
#endif

#if defined (LINUX) && defined (G_A64) && !defined (ARM)
# define LONG int
# define ULONG unsigned int
#else
# define LONG long
# define ULONG unsigned long
#endif
#define BYTE char
#define UBYTE unsigned char

#define VOID void

#ifdef THINK_C
#	define DOUBLE short double
#else
#	define DOUBLE double
#endif

#if ! (defined (sparc) || defined (I486) || defined (ARM) || defined (G_POWER))
#	define M68000
#endif

#ifndef G_A64
# define STACK_ELEMENT_SIZE 4
# define STACK_ELEMENT_LOG_SIZE 2
# define CleanInt LONG
#else
# define STACK_ELEMENT_SIZE 8
# define STACK_ELEMENT_LOG_SIZE 3
# if defined (LINUX)
#  define CleanInt int64_t
#  define int_64 int64_t
#  define uint_64 uint64_t
# else
#  define CleanInt __int64
#  define int_64 __int64
#  define uint_64 unsigned __int64
# endif
#endif

#if defined (I486) || defined (ARM) || (defined (G_POWER) || defined (ALIGN_C_CALLS)) || defined (MACH_O)
# define SEPARATE_A_AND_B_STACK_OVERFLOW_CHECKS
#endif

#ifdef __MWERKS__
int mystrcmp (char *p1,char *p2);
#define strcmp(s1,s2) mystrcmp(s1,s2)
#endif
