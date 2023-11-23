
#define CLEAN2 1

#define STORE_STRICT_CALL_NODES 1
#undef OBSERVE_ARRAY_SELECTS_IN_PATTERN

#define ABSTRACT_OBJECT 1 /* bug fix */

#define TRANSFORM_PATTERNS_BEFORE_STRICTNESS_ANALYSIS
#define IMPORT_OBJ_AND_LIB 1

#define WRITE_DCL_MODIFICATION_TIME 1

#define SA_RECOGNIZES_ABORT_AND_UNDEF 1

#define STRICT_LISTS 1
#define BOXED_RECORDS 1

#define NEW_APPLY

#define LIFT_PARTIAL_APPLICATIONS_WITH_ZERO_ARITY_ARGS

#ifdef NO_CLIB

#include <stdlib.h>
#include "clib_functions.h"

# ifndef DEFINE_MEMCPY
#  define memcpy clean_compiler_memcpy
# endif
#define strcpy clean_compiler_strcpy
#define strcat clean_compiler_strcat
#define strncpy clean_compiler_strncpy
#define strcmp clean_compiler_strcmp
#define strncmp clean_compiler_strncmp
#define strlen clean_compiler_strlen

#define clean_compiler_isdigit(c) (((unsigned int)(c)-48u)<=9u)
#define clean_compiler_isspace(c) ((c)==' ' || (((unsigned int)(c)-9u)<=4u))

#endif
